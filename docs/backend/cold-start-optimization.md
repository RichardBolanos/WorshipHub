# Cold start optimization — Spring Boot + GraalVM native image en Render Free Tier

> ## ✅ Estado: IMPLEMENTADO Y VERIFICADO EN PRODUCCIÓN
>
> Este documento describe trabajo **ya realizado y medido en prod**.
> El cold start pasó de ~34 s a **14.3 s medidos en Render** tras tres
> rondas de optimización + migración a Spring Boot 4.0. No es un TODO.
>
> Todas las optimizaciones descritas están aplicadas, cubiertas por tests
> de regresión (ver sección [Tests de regresión](#tests-de-regresión-pinning-the-contract))
> y verificadas en CI con un smoke test que arranca el contexto del perfil
> `prod` contra una DB inalcanzable. **No volver a "implementar" estos
> cambios** — si algún test del paquete `coldstart` empieza a fallar,
> trátalo como una regresión, no como una sugerencia.
>
> Si necesitás revertir alguno de estos cambios, hacelo de forma
> consciente y actualizá el test correspondiente para documentar el
> trade-off. Nunca aflojes los tests para hacer pasar un cambio que los
> rompe.

---

## Resumen ejecutivo

Tres rondas de optimización + una migración mayor a Spring Boot 4.0
para habilitar Spring Data JPA AOT repositories. Cada round con
mediciones reales en Render free tier.

| Métrica                      | Antes (3.5.5)| Round 1 medido      | Round 3 medido       | Cómo medir                                               |
| ---------------------------- | ------------ | ------------------- | -------------------- | -------------------------------------------------------- |
| **Cold start total**         | ~34 s        | 28.6 s              | **14.3 s** ✅         | `curl /api/v1/health \| jq .startup.timeToReadyMs`       |
| `singletonsMs` phase         | no medido    | 28 289 ms           | **14 001 ms**        | log `ColdStart phases={...}` en stdout                   |
| `jpaSongRepository` init     | no medido    | 13 890 ms           | **<200 ms** (AOT)    | log `Slow bean init: ...`                                |
| `mvcHandlerMappingIntrospector` | no medido | 1 202 ms            | **0 ms** (excluido)  | mismo log                                                |
| `entityManagerFactory`       | no medido    | 4 873 ms            | 4 790 ms (floor)     | mismo log                                                |
| Conexiones DB en boot        | 1+ bloqueante | **0** (verificado por test) | **0**         | smoke test `ProdProfileContextLoadsWithoutDbSmokeTest`   |
| Stack traces de scrapers     | sí           | sí                  | **0** (404 silenciado) | logs de Render                                          |
| Hibernate WARN en boot       | 2 (`HHH9000…`) | 0                | **0**                | logs de Render                                            |
| Spring Boot                  | 3.5.5        | 3.5.5               | **4.0.6**            | `curl /api/v1/health \| jq .version`                     |

**Mejora total: 34 s → 14.3 s = -58 %.** El número que importa para
monitoreo continuo es `timeToReadyMs`, expuesto en el endpoint de
health (ver [Telemetría](#telemetría-server-side)).

### Floor teórico alcanzado

Tras Round 3 el cold start está cerca del floor práctico para esta
arquitectura. El desglose medido en Render:

```
ColdStart timeToReady=14308ms phases={
  jvmToFrameworkMs=13,    ← container scheduling + native binary start
  environmentMs=193,      ← profile + property sources
  contextInitMs=9,        ← context creation
  beanDefinitionsMs=0,    ← bean definitions parsing
  singletonsMs=14001,     ← 98% del tiempo total — donde vive todo lo restante
  postSingletonsMs=91,    ← context refresh tail
  runnersMs=1             ← @ApplicationRunner / @CommandLineRunner
}
```

Los 14 s de `singletonsMs` se reparten así:

| Bean                              | ms     | Reducible? |
| --------------------------------- | ------ | ---------- |
| Hibernate `entityManagerFactory`  | 4 790  | No (23 entities, metamodel inevitable) |
| `jpaUserRepository` (sigue eager) | 586    | Marginalmente |
| `correlationIdFilter`             | 391    | No (Tomcat init)            |
| `tomcatServletWebServerFactory`   | 202    | No (Tomcat boot)            |
| Otros singletons + AOT context    | ~8 000 | Sub-200 ms cada uno, suma irreducible |

Bajar de 14 s requeriría cambios arquitecturales mayores (ver
[Cosas que deliberadamente NO se hicieron](#cosas-que-deliberadamente-no-se-hicieron)).

---

## Contexto y stack técnico

API Spring Boot 4.0.6 + Kotlin 2.2 compilada como GraalVM native image,
desplegada en Render free tier. El cold start original (~34 s) se debía
casi enteramente a I/O bloqueante durante el context refresh, no al
arranque del binario nativo (~1–2 s).

**Stack actual** (post-Round 3):

- Spring Boot **4.0.6** + Kotlin **2.2.20** (era 3.5.5 + Kotlin 2.1)
- Spring Framework 7.0, Spring Data JPA 4.0, Spring Security 7.0
- Hibernate 7.1, Jackson 3.0
- GraalVM native image (`graalvm-community:25`, era 21)
- Gradle wrapper **9.5.0** (era 8.14.3)
- GraalVM Native Build Tools **1.1.0** (era 0.10.6)
- Foojay Resolver **1.0.0** (era 0.10.0)
- Render free tier (container muere tras inactividad, `min-instances=0`)
- Neon Postgres free tier (suspende compute tras 5 min, wake-up 5–10 s)
- Firebase Admin SDK 9.3.0 (push notifications)
- Flyway migrations (18 archivos)
- HikariCP connection pool

> ⚠️ **Cadena de constraints de toolchain** (importante si alguien
> upgradea componentes individualmente): SB4 requiere GraalVM 25, que
> provee Java 25, que requiere Gradle 9.1+. Gradle 9 removió
> `JvmVendorSpec.IBM_SEMERU` que era referenciado por NBT < 1.1.0 **y
> por foojay-resolver < 1.0.0** (descubierto en producción tras el
> upgrade — el plugin de foojay vive en `settings.gradle.kts` no
> `build.gradle.kts`, fácil de pasar por alto). Si bumeás Gradle, bumeá
> los dos.

### Causa raíz del cold start original

El native image arranca en ~1–2 s. Los ~32 s restantes eran I/O
bloqueante en el context refresh:

1. Neon DB wake-up (5–10 s) bloqueando el arranque por culpa de Hikari
   `connection-timeout: 20000` + Hibernate `validate`.
2. HikariCP esperando primera conexión.
3. Flyway ejecutando 18 migraciones en cada startup (3–5 s).
4. Firebase Admin SDK haciendo HTTP a Google para inicializar (2–5 s).
5. Render container scheduling (2–3 s, fuera de nuestro control).
6. **`jpaSongRepository` parsing 7 `@Query` HQL en runtime (13.9 s)** —
   descubierto sólo tras instrumentar (Round 2), eliminado en Round 3
   con Spring Data JPA AOT repositories.

---

## Restricciones de diseño

Estas restricciones siguen vigentes para cualquier cambio futuro:

- ❌ **NO** cambiar de free tier (ni Render ni Neon).
- ❌ **NO** agregar `min-instances > 0`.
- ❌ **NO** cambiar la estructura de módulos (`api`, `application`,
  `domain`, `infrastructure`).
- ❌ **NO** usar `spring.main.lazy-initialization=true` global (rompe
  cosas de forma sutil — `@Scheduled`, `@EventListener`, `@PostConstruct`).
- ✅ Mantener compatibilidad con perfiles `local` / `dev` / `h2` (que sí
  usan Flyway enabled, Firebase eager, Hikari normal).
- ✅ Cambios solo en perfil `prod` o condicionales por perfil.

---

## Cambios implementados

Lista canónica de las optimizaciones y dónde viven. Cada una tiene un
test de regresión que la pin (ver tabla al final).

### 1. Lazy initialization de Firebase

**Archivos**:
- `api/src/main/kotlin/com/worshiphub/api/config/FirebaseConfig.kt`
- `infrastructure/src/main/kotlin/com/worshiphub/infrastructure/push/FirebasePushGateway.kt`

`@Lazy` en los beans `firebaseApp()` y `firebaseMessaging()` **y
`ObjectProvider<FirebaseMessaging>` en el constructor de
`FirebasePushGateway`**.

> ⚠️ **Detalle crítico — NO usar `@Lazy` en el call site con
> native image**: la versión inicial usaba
> `@Lazy private val firebaseMessaging: FirebaseMessaging?` en el
> constructor, lo que funciona en JVM normal porque Spring genera
> una subclase CGLIB de `FirebaseMessaging` al vuelo como proxy
> lazy. Pero en GraalVM **native image arranca con**:
>
> ```
> AopConfigException: Could not generate CGLIB subclass of
> class com.google.firebase.messaging.FirebaseMessaging
> ...
> NoSuchMethodException: FirebaseMessaging$$SpringCGLIB$$0
>   .CGLIB$SET_THREAD_CALLBACKS(...)
> ```
>
> porque los métodos CGLIB generados dinámicamente no están
> registrados como metadata reflectiva en el AOT-built native image.
>
> La solución correcta es `ObjectProvider<FirebaseMessaging>`: es la
> API que Spring Boot usa internamente para inyección lazy
> AOT/native-friendly, **no requiere proxy CGLIB**, y produce el
> mismo deferral. El AOT bean definition resultante es:
>
> ```java
> BeanInstanceSupplier.<FirebasePushGateway>forConstructor(ObjectProvider.class)
>     .withGenerator((registeredBean, args) -> new FirebasePushGateway(args.get(0)));
> ```
>
> Verificable inspeccionando
> `api/build/generated/aotSources/.../FirebasePushGateway__BeanDefinitions.java`
> tras correr `./gradlew :api:processAot`.
>
> El test
> `FirebasePushGatewayTest > "constructor parameter must be ObjectProvider, not @Lazy"`
> previene la regresión hacia `@Lazy`.

Firebase ahora se inicializa al primer push notification, no al
arrancar la app (ahorro: 2–5 s).

### 2. HikariCP no bloquea startup

**Archivo**: `api/src/main/resources/application-prod.yml`

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: ${DB_POOL_SIZE:3}
      minimum-idle: ${DB_POOL_MIN_IDLE:0}     # ← NO pre-warmear
      connection-timeout: 10000               # ← era 20000
      initialization-fail-timeout: -1         # ← NO validar pool en boot
      idle-timeout: 300000
      max-lifetime: 900000
      leak-detection-threshold: 60000
```

Con `minimum-idle: 0` no abre conexión al arrancar. Con
`initialization-fail-timeout: -1` Hikari no valida el pool durante
startup. La primera query real es la que paga el wake-up de Neon
(ahorro: hasta 10 s).

### 3. Hibernate no ejecuta queries de metadata en boot

**Archivo**: `api/src/main/resources/application-prod.yml`

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: ${DDL_AUTO:none}              # ← era 'validate'
    defer-datasource-initialization: true
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    properties:
      hibernate:
        boot:
          allow_jdbc_metadata_access: false
```

Cuatro cosas pasando aquí:

- **`ddl-auto: none`** (no `validate`). `validate` abre conexión durante
  `EntityManagerFactory.afterPropertiesSet()` para comparar entidades
  con schema vivo, anulando el `minimum-idle: 0`. Schema integrity está
  garantizada por Flyway en CI/deploy, no por validación en runtime.
- **`defer-datasource-initialization: true`**: evita que Spring abra una
  conexión para correr `schema.sql` / `data.sql` (que en prod no existen).
- **`allow_jdbc_metadata_access: false`**: skip al probe de metadata
  JDBC que Hibernate corre al arrancar para detectar dialecto. Reemplaza
  al deprecated `hibernate.temp.use_jdbc_metadata_defaults` (Hibernate
  6.6+).
- **`database-platform: PostgreSQLDialect` es OBLIGATORIO**. Sin
  metadata access, Hibernate no puede auto-detectar el dialecto.
  Verificado experimentalmente: removerlo causa
  `HibernateException: Unable to determine Dialect without JDBC metadata`.

> ⚠️ **No te dejes confundir por el WARN `HHH90000025`**. Hibernate
> loguea `PostgreSQLDialect does not need to be specified explicitly`,
> pero ese mensaje asume que metadata está accesible. En nuestra
> configuración SÍ es necesario. El logger
> `org.hibernate.orm.deprecation` está silenciado a `ERROR` en prod
> precisamente para eliminar este falso positivo.

### 4. Flyway deshabilitado por default en prod

**Archivos**:
- `api/src/main/resources/application-prod.yml`
- `api/src/main/resources/application.yml`

```yaml
# application-prod.yml
spring:
  flyway:
    enabled: ${FLYWAY_ENABLED:false}          # ← era 'true'

# application.yml (defaults para todos los perfiles)
spring:
  flyway:
    connect-retries: 1                        # ← era 3
    connect-retries-interval: 5
```

En cold starts normales por inactividad **no hay migraciones que
correr**. Ejecutar Flyway igualmente en cada wake-up costaba 3–5 s
inútiles. Ver [operativa de despliegue](#operativa-de-despliegue) para
el flow correcto al introducir migraciones nuevas.

### 5. MailConfigValidator no aborta startup

**Archivo**: `infrastructure/src/main/kotlin/com/worshiphub/infrastructure/email/MailConfigValidator.kt`

Antes lanzaba `IllegalStateException` en prod si faltaba
`APP_EMAIL_FROM` / `APP_BASE_URL` / `SPRING_MAIL_HOST`. **Ya no.** Ahora
loguea ERROR + reporta `DOWN` en `/actuator/health`, pero la app
arranca igualmente.

> 💡 **Razonamiento**: en Render free tier, abortar startup convierte
> "email mal configurado" en "API completamente caída" (health check
> falla, Render marca el servicio rojo, todos los endpoints mueren). Es
> estrictamente peor que servir tráfico con email degradado. El log
> ERROR es lo suficientemente ruidoso para que ops lo vea, y los emails
> fallarán visiblemente en el call site.

### 6. ReminderSchedulerJob no dispara DB query en cold start

**Archivo**: `application/src/main/kotlin/com/worshiphub/application/notification/ReminderSchedulerJob.kt`

```kotlin
@Scheduled(fixedRate = FIXED_RATE_MS, initialDelay = INITIAL_DELAY_MS)
fun checkUpcomingServices() { ... }
```

Antes era `@Scheduled(fixedRate = 900_000)` **sin `initialDelay`**, lo
que disparaba una query JPA en los primeros segundos del cold start,
forzando el wake-up de Neon en el thread de la primera petición.

Este bug fue **descubierto por el smoke test** del perfil prod — sin
él habría seguido invisible en CI y caro en producción. El job ahora
espera 60 s antes de su primera ejecución, dando tiempo a que la
request que causó el wake-up complete primero.

### 7. Health check apunta a endpoint DB-free

**Configuración manual en Render** (no se puede automatizar desde el
repo): el **Health Check Path** del servicio debe ser:

```
/api/v1/health
```

| Endpoint                | Toca DB | Apto health check                        |
| ----------------------- | ------- | ---------------------------------------- |
| `/api/v1/health`        | NO      | ✅ **SÍ — el correcto**                  |
| `/api/v1/system/health` | SÍ      | ❌ Falla durante el wake-up de Neon      |
| `/actuator/health`      | SÍ      | ❌ Incluye DB y mail health indicators   |

---

## Telemetría server-side

`/api/v1/health` expone un bloque `startup` con métricas reales del
cold start, **desglosado por fase del lifecycle de Spring** y con la
lista de beans cuya inicialización cruzó un threshold. Implementado
por:

- `api/src/main/kotlin/com/worshiphub/api/health/StartupTimestampRecorder.kt` —
  recorder de fases (delega a un `object` global `StartupTimings`)
- `api/src/main/kotlin/com/worshiphub/api/health/SlowBeanInitLogger.kt` —
  `BeanPostProcessor` que mide cada bean y registra los lentos

Ejemplo de respuesta tras un cold start optimizado:

```json
{
  "status": "UP",
  "service": "WorshipHub API",
  "version": "1.0.5",
  "timestamp": "2026-05-20T05:18:42.123",
  "uptime": "running",
  "startup": {
    "jvmStartedAt": "2026-05-20T05:18:35.420Z",
    "applicationReadyAt": "2026-05-20T05:18:41.654Z",
    "jvmUptimeMs": 6890,
    "timeToReadyMs": 6234,
    "ready": true,
    "phases": {
      "jvmToFrameworkMs":  812,
      "environmentMs":     145,
      "contextInitMs":      63,
      "beanDefinitionsMs": 290,
      "singletonsMs":     4123,
      "postSingletonsMs":  743,
      "runnersMs":          58
    },
    "slowBeans": {
      "entityManagerFactory": 3812,
      "flywayInitializer":     452,
      "tomcatWebServerFactory": 287
    },
    "slowBeanThresholdMs": 200
  },
  "databaseWarmup": {
    "warmedUp": true,
    "warmedUpAt": "2026-05-20T05:18:46.475Z",
    "durationMs": 4821
  }
}
```

> El bloque `databaseWarmup` lo provee `DatabaseWarmupRunner`, agregado
> en Round 4. Mide cuánto tarda Neon en despertar tras
> `ApplicationReadyEvent`. Detalles en [Round 4](#round-4-async-db-warmup).

### Fases del cold start (mapa de qué mide cada delta)

| Fase                | Mide                                                             |
| ------------------- | ---------------------------------------------------------------- |
| `jvmToFrameworkMs`  | Container scheduling + JVM warm-up + Spring framework load       |
| `environmentMs`     | Resolución de profile + property sources                         |
| `contextInitMs`     | Instanciación del `ApplicationContext`                           |
| `beanDefinitionsMs` | `@ComponentScan` + parsing de `@Configuration`                   |
| **`singletonsMs`**  | **Instanciación de singletons (Hibernate EMF, Flyway, etc.) — usualmente la fase grande** |
| `postSingletonsMs`  | Tail del context refresh: arranque de Tomcat, etc.               |
| `runnersMs`         | Ejecución de `CommandLineRunner` / `ApplicationRunner`           |

### Campos top-level

| Campo                   | Significado                                                              |
| ----------------------- | ------------------------------------------------------------------------ |
| `jvmStartedAt`          | Wall-clock cuando el container forkeó la JVM                             |
| `applicationReadyAt`    | Wall-clock cuando Spring publicó `ApplicationReadyEvent`                 |
| `jvmUptimeMs`           | Tiempo desde JVM start hasta esta request                                |
| **`timeToReadyMs`**     | **`applicationReadyAt − jvmStartedAt` — la métrica headline**            |
| `ready`                 | `false` si la probe llegó antes de `ApplicationReadyEvent`               |
| `phases`                | Map fase → ms (entradas faltantes si la probe llegó mid-startup)         |
| `slowBeans`             | Beans cuya init cruzó el threshold (default 200 ms)                      |
| `slowBeanThresholdMs`   | Threshold actual (configurable con env var `STARTUP_SLOW_BEAN_THRESHOLD_MS`) |

### Log automático en cada cold start

Al disparar `ApplicationReadyEvent` la app loguea una línea grep-friendly:

```
ColdStart timeToReady=6234ms phases={jvmToFrameworkMs=812, environmentMs=145, ...}
```

Esto significa que **no es necesario hacer curl** para tener el
breakdown — Render captura stdout y la línea queda en el log stream
del deploy. Beans lentos también se loguean uno por línea conforme
cruzan el threshold:

```
Slow bean init: name='entityManagerFactory' type='org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean' tookMs=3812
Slow bean init: name='flywayInitializer' type='...' tookMs=452
```

### Cómo diagnosticar un cold start lento

1. **Mirar el log stream de Render** — la línea `ColdStart …` da el
   breakdown sin necesidad de curl.
2. **Identificar la fase grande** en `phases`. La candidata habitual
   es `singletonsMs`.
3. **Mirar las líneas `Slow bean init: …`** del mismo cold start
   para identificar qué bean específico es responsable.
4. **Si la fase grande es `jvmToFrameworkMs`** (>5 s), el problema
   está antes de Spring — JVM/container scheduling. Fuera de nuestro
   alcance en free tier.
5. **Si `runnersMs` es alto**, algún `CommandLineRunner` /
   `ApplicationRunner` está haciendo I/O síncrono en startup. Tip:
   `DataInitializer` es el sospechoso obvio.

```bash
# Capturar timings desde fuera (también funciona con un curl):
curl https://worshiphub-api-latest.onrender.com/api/v1/health \
  | jq '.startup | {timeToReadyMs, phases, slowBeans}'
```

### Tuning del threshold

El default de 200 ms se puede bajar para una sesión de debugging:

```bash
# En Render → Environment, agregar temporalmente:
STARTUP_SLOW_BEAN_THRESHOLD_MS=50
```

Esto loguea cada bean que tarde >50 ms en construirse — más ruidoso
pero útil para localizar regresiones graduales (e.g. una migración
nueva de Hibernate añade entidades). Volver a 200 ms (o quitar la
var) tras el diagnóstico.

### Limitaciones conocidas

- Las fases tempranas (`jvmToFrameworkMs`, `environmentMs`,
  `contextInitMs`, `beanDefinitionsMs`) **solo se registran si la app
  arranca por `main()`**. En `@SpringBootTest` el contexto se
  construye internamente y esos timestamps quedan `null`. No es un
  problema para producción: solo para tests, donde no medimos cold
  start de todas formas.
- El `BeanPostProcessor` añade ~50 ns por bean. Despreciable en
  startup (200+ beans) pero medido por completitud.

---

## Operativa de despliegue

### Deploy normal (sin migraciones nuevas)

1. Push a la rama de deploy.
2. Render reconstruye y deploya.
3. Cold start tarda ~5–7 s (verificable por `timeToReadyMs`).

`FLYWAY_ENABLED` debe estar **ausente o en `false`**.

### Deploy con migraciones nuevas

1. En Render → **Environment**, set `FLYWAY_ENABLED=true`.
2. Triggerear deploy.
3. Verificar logs: `Flyway` debe loguear "Migration X applied".
4. **Volver a setear `FLYWAY_ENABLED=false`** (o remover la var).
5. Triggerear un redeploy "vacío" para que el próximo cold start vuelva
   a ser rápido. (Render no re-ejecuta el deploy solo por cambio de
   env var, así que hay que forzarlo.)

> Si te olvidás del paso 4-5, los próximos cold starts seguirán
> corriendo Flyway igualmente (idempotente, pero +3–5 s desperdiciados
> por wake-up).

---

## Limpieza de warnings y autoconfig en prod

Optimizaciones puntuales aplicadas tras observar el log de un cold
start real en Render. Cada una elimina un warning que distraía del
diagnóstico O incluía beans innecesarios en la imagen nativa.

### 8. Excluir `UserDetailsServiceAutoConfiguration`

**Archivo**: `api/src/main/kotlin/com/worshiphub/WorshipHubApplication.kt`

```kotlin
@SpringBootApplication(
    scanBasePackages = ["com.worshiphub"],
    exclude = [UserDetailsServiceAutoConfiguration::class]
)
```

Sin esto, Spring Security autoconfiguraba un `inMemoryUserDetailsManager`
con password aleatorio que se logueaba en cada cold start
(`Using generated security password: ...`). La API usa JWT, no Basic /
form login, así que el bean es dead-weight + leak de credenciales.
Excluirlo elimina el WARN y reduce la superficie de ataque.

### 9. Eliminar `ValidationConfig` (duplicado de Spring Boot autoconfig)

**Archivo**: `api/src/main/kotlin/com/worshiphub/api/config/ValidationConfig.kt` (eliminado)

Spring Boot's `ValidationAutoConfiguration` ya provee `Validator` y
`MethodValidationPostProcessor` con la convención correcta (`static
@Bean` en autoconfig). Tener nuestro propio `ValidationConfig`
disparaba el WARN
`Bean 'validationConfig' is not eligible for getting processed by all
BeanPostProcessors` porque el `methodValidationPostProcessor` se
declaraba como factory method no-static. Borrar el archivo no rompe
nada — la autoconfig de Spring Boot toma el relevo.

### 10. Deshabilitar springdoc al ROOT (no solo `api-docs.enabled`)

**Archivo**: `api/src/main/resources/application-prod.yml`

```yaml
springdoc:
  enabled: false           # ← ROOT switch (excluye toda la auto-config)
  api-docs:
    enabled: false
  swagger-ui:
    enabled: false
```

Setear solo `springdoc.api-docs.enabled: false` no impide que Spring
construya el bean `SpringDocAppInitializer`, que en springdoc 2.8.17
**tiene un bug**: la condición del log está invertida y dispara un WARN
("`SpringDoc /v3/api-docs endpoint is enabled by default`") **cuando
ya está disabled**. La forma correcta es deshabilitar al root con
`springdoc.enabled: false`, lo que hace match con el
`@ConditionalOnProperty(name = SPRINGDOC_ENABLED, matchIfMissing = true)`
en `SpringDocConfiguration` y excluye toda la auto-config en cascada.

### 11. Activar el perfil `prod` durante AOT processing

**Archivos**:
- `api/build.gradle.kts` (system property en `processAot`)
- `Dockerfile.native` (flag en `nativeCompile`)

```kotlin
tasks.named<JavaExec>("processAot") {
    systemProperty("spring.profiles.active", "prod")
    systemProperty("DATABASE_URL", "jdbc:postgresql://aot-build-placeholder:5432/aot")
    systemProperty("SPRING_MAIL_HOST", "aot-build-placeholder")
}
```

Spring Boot 3 evalúa `@ConditionalOnProperty` y `@Profile` **en build
time** y bakea el resultado en la imagen nativa. Por defecto el AOT
runner no tiene perfil activo, así que beans guardados con
`@Profile("prod")` o por flags solo presentes en
`application-prod.yml` (como `springdoc.enabled: false`) se cuelan en
la imagen aunque deberían estar excluidos.

Activando `spring.profiles.active=prod` durante AOT, los conditionals
se resuelven contra el perfil real de producción y los beans no usados
se eliminan del bean graph estático. Verificable inspeccionando
`api/build/generated/aotSources/` antes y después: SpringDoc desaparece.

Los placeholders dummy de `DATABASE_URL` y `SPRING_MAIL_HOST` son
porque el AOT resolver de `@Value("${...}")` no acepta placeholders
sin default. Los valores **no se usan en runtime** — Render inyecta
los reales al arrancar el container.

### 12. Hint de runtime para resources de Flyway en native image

**Archivo**: `api/src/main/kotlin/com/worshiphub/KotlinEmptyCollectionHints.kt`
(nueva clase `FlywayMigrationsRuntimeHints`)

Sin este hint, Flyway escanea el classpath en native image y falla con
`Unable to scan location: /db/migration (unsupported protocol: resource)`
porque el protocolo `resource:` de GraalVM no es entendido por el
`ClassPathScanner` de Flyway. Las migraciones igualmente se ejecutan
gracias a Spring Boot autoconfig que las pasa explícitamente, pero el
WARN ensucia el log.

Registrando `db/migration/*` y `db/migration/*.sql` como resource
patterns en `RuntimeHintsRegistrar`, Flyway las encuentra a través de
`ClassLoader.getResources()` (su lookup secundario) y el WARN
desaparece.

### 13. Silenciar loggers de warnings inevitables

**Archivo**: `api/src/main/resources/application-prod.yml`

```yaml
logging:
  level:
    org.hibernate.orm.deprecation: ERROR    # falso positivo HHH90000025
    io.micrometer.core.instrument.binder.jvm.JvmGcMetrics: ERROR
    org.flywaydb.core.internal.scanner.classpath.ClassPathScanner: ERROR
```

Tres warnings que NO se pueden arreglar sin cambios estructurales:

- **HHH90000025** (Hibernate dialect): falso positivo en nuestra
  config (ver optimización #3).
- **JvmGcMetrics**: GraalVM Serial GC no implementa
  `NotificationEmitter` en `GarbageCollectorMXBean`. Cambiar de GC
  está fuera de alcance del free tier.
- **Flyway ClassPathScanner**: incluso con el hint del #12, Flyway
  loguea el WARN durante el scan inicial antes de usar el lookup
  secundario.

Bajar estos loggers a `ERROR` los silencia sin afectar señales reales
de problemas.

---

## Optimizaciones basadas en mediciones reales (round 2)

Tras instrumentar el cold start y observar un cold start real en
Render (28.6 s con la base optimizada), el desglose mostró:

| Bean                              | Tiempo  | Acción aplicada                              |
| --------------------------------- | ------- | -------------------------------------------- |
| `jpaSongRepository`               | 13.9 s  | `bootstrap-mode: lazy` (#14)                 |
| `entityManagerFactory`            |  4.9 s  | Inevitable; necesario para JPA               |
| `mvcHandlerMappingIntrospector`   |  1.2 s  | `management.observations.enable.spring.security: false` (#15) |
| `jpaRefreshTokenRepository`       |  0.8 s  | `bootstrap-mode: lazy` (#14)                 |
| `tomcatServletWebServerFactory`   |  0.4 s  | Inevitable                                   |
| `jpaGlobalSongRepository`         |  0.3 s  | `bootstrap-mode: lazy` (#14)                 |

Las decisiones de qué pelear y qué aceptar:

- ✅ **Pelear**: `jpaSongRepository` (13.9 s) y observabilidad de
  Spring Security (1.2 s). Los repositorios JPA son la mejor
  oportunidad — Spring Data soporta lazy bootstrap nativamente.
- ❌ **Aceptar**: `entityManagerFactory` (4.9 s). Hibernate construye
  el metamodelo de 23 entidades en native image; reducirlo
  requeriría borrar entidades reales o cambiar a Spring Data JDBC,
  ambas decisiones de producto.
- ❌ **Aceptar**: Wake-up de Neon (~7 s entre Hikari start y primer
  query). No mitigable en free tier.

### 14. `bootstrap-mode: lazy` para repositorios JPA

**Archivo**: `api/src/main/resources/application-prod.yml`

```yaml
spring:
  data:
    jpa:
      repositories:
        bootstrap-mode: lazy
```

Por defecto Spring Data JPA instancia **todos los `@Repository`** en el
context refresh, validando cada `@Query` contra el metamodel. En modo
lazy, **cada repositorio se construye al primer uso**.

`jpaSongRepository` tiene 7 queries `@Query` HQL sobre `Song` (entidad
con 3 asociaciones `@ManyToMany`/`@OneToMany`). Hibernate parsea + valida
cada una contra el metamodel — 13.9 s en native image.

**Trade-off explícito**: el primer request de un endpoint que use ese
repositorio paga el costo deferido. Es aceptable porque:
1. El health probe (`/api/v1/health`) NUNCA toca un repository JPA.
2. Cualquier request real tras un cold start ya paga el wake-up de
   Neon (~5–10 s); +13 s adicionales en una request específica es
   menos malo que +13 s en cada cold start del health probe.

### 15. Deshabilitar Spring Security observations

**Archivo**: `api/src/main/resources/application-prod.yml`

```yaml
management:
  observations:
    enable:
      spring.security: false
```

Spring Boot wirea `mvcHandlerMappingIntrospector` cuando hay
observability de Spring Security activa, para taggear cada
observación con el `@RequestMapping` que la atendió. Pero el
introspector pesa 1.2 s en cold start y los datos solo importan si
exportamos métricas/traces — algo que NO hacemos en prod (no hay
backend de telemetría conectado).

Apagarlo elimina el bean del context refresh con cero impacto
funcional: la seguridad sigue funcionando, simplemente no
recolectamos timing por filtro.

### 16. Manejar `NoResourceFoundException` silenciosamente

**Archivo**: `api/src/main/kotlin/com/worshiphub/api/config/GlobalExceptionHandler.kt`

Spring 6 lanza `NoResourceFoundException` cuando llega una request a
un path sin handler estático (típicamente scrapers buscando
`/swagger-ui/index.html`, `/.env`, `/wp-login.php`, …). El handler
genérico `Exception` la pescaba y logueaba un stack trace de >150
líneas como ERROR.

Añadido un handler específico que retorna 404 con un solo log line
DEBUG — el ruido de scrapers ya no contamina logs ni dispara alertas
de "errores en producción".

### Round 3: Spring Boot 4.0 + Spring Data JPA AOT repositories ✅ APLICADO Y VERIFICADO

**Status**: implementado y **medido en producción** — cold start cae
de 28.6 s (Round 1 medido) a **14.3 s** (Round 3 medido en Render).
La métrica `jpaSongRepository` baja de 13 890 ms a sub-200 ms (deja
de aparecer en `slowBeans` enteramente).

#### Por qué se decidió migrar a SB4

Tras instrumentar el cold start (Round 2), el log de Render mostró
que `jpaSongRepository` solo tomaba 13.9 s — el 48 % del cold start
budget. Este repositorio tiene 7 `@Query` HQL sobre una entidad
con tres asociaciones `@ManyToMany`/`@OneToMany`. En cada startup,
Spring Data JPA 3.x parsea y valida cada query reflectivamente
contra el metamodel de Hibernate.

**Spring Data JPA 4.0** (incluido en Spring Boot 4) introdujo AOT
repositories: pre-genera el bytecode de los query methods en build
time. En runtime, las queries son strings literales en una clase
estática — sin reflection, sin parsing, sin validación dinámica.

Sin esa feature, el cap del cold start estaba en ~28 s. Con ella,
en ~14 s.

#### Configuración

`api/build.gradle.kts` (system property al `processAot` task —
no se setea via YAML porque queremos que aplique al BUILD, no al
runtime):

```kotlin
tasks.named<JavaExec>("processAot") {
    systemProperty("spring.profiles.active", "prod")
    systemProperty("spring.aot.repositories.enabled", "true")
    systemProperty("DATABASE_URL", "jdbc:postgresql://aot-build-placeholder:5432/aot")
    systemProperty("SPRING_MAIL_HOST", "aot-build-placeholder")
}
```

**Verificable en build output**: tras `./gradlew :api:processAot`,
mira `api/build/generated/aotSources/com/worshiphub/infrastructure/repository/`.
Hay 22 archivos `*Impl__AotRepository.java` (uno por repositorio JPA)
con **bytecode estático para cada `@Query`**. Ejemplo
(`JpaSongRepositoryImpl__AotRepository.java`):

```java
public boolean existsByTitleAndArtistAndChurchId(String title, String artist, UUID churchId) {
    String queryString = "SELECT s.id FROM Song s WHERE s.title = :title AND s.artist = :artist AND s.churchId = :churchId";
    Query query = this.entityManager.createQuery(queryString);
    query.setParameter("title", title);
    query.setParameter("artist", artist);
    query.setParameter("churchId", churchId);
    query.setMaxResults(1);
    return !query.getResultList().isEmpty();
}
```

**Combinado con `bootstrap-mode: lazy`**: incluso la primera request
real ya no paga query compilation — solo el wake-up de Neon (~5–10 s).

#### Cambios de dependencia (orden de descubrimiento)

La migración disparó una cascada de upgrades obligatorios:

- **Spring Boot 3.5.5 → 4.0.6**
- **Kotlin 2.1.0 → 2.2.20** (con `-Xannotation-default-target=param-property`
  para silenciar KT-73255 sobre `@Value` en constructor params)
- **Hibernate 6.6 → 7.1** (auto-managed por SB4 BOM)
- **Jackson 2 → Jackson 3** (`com.fasterxml.jackson.databind` →
  `tools.jackson.databind`, `ObjectMapper` → `JsonMapper`)
- **Spring Security 6 → 7**
- **springdoc-openapi 2.8.17 → 3.0.3** (la versión SB4-compatible —
  2.x referencia `org.springframework.boot.autoconfigure.web.servlet.
  WebMvcProperties` que SB4 relocó, rompiendo todo `@SpringBootTest`
  con `NoClassDefFoundError`)
- **springmockk 4.0.2 → 5.0.1** (SB4 / `@MockitoBean` semantics)
- **GraalVM 21 → 25** (`Dockerfile.native` — requirement de SB4 para
  native image)
- **Eliminado `spring-retry`** (no se usaba — solo `@EnableRetry`
  como anotación dead, sin ningún `@Retryable`. SB4 BOM no la maneja)

**Package moves arreglados**:

- `org.springframework.boot.actuate.health.{Health, HealthIndicator}` →
  `org.springframework.boot.health.contributor.{Health, HealthIndicator}`
- `org.springframework.boot.autoconfigure.domain.EntityScan` →
  `org.springframework.boot.persistence.autoconfigure.EntityScan`
- `org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration` →
  `org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration`
- `org.springframework.boot.test.autoconfigure.web.servlet.{WebMvcTest, AutoConfigureMockMvc}` →
  `org.springframework.boot.webmvc.test.autoconfigure.{WebMvcTest, AutoConfigureMockMvc}`

**API breaks arreglados**:

- `CommandLineRunner.run`: `vararg String?` → `vararg String` (NullAway-friendly)
- `FilterRegistrationBean.{filter, order}`: ahora `val`, usar setters
- `GrantedAuthority.authority` ahora nullable (Spring Security 7) →
  filtrar nulls con `mapNotNull`
- `MessageSource.getMessage` args: `Array<Any?>?` → `Array<out Any>?`

**Eliminado**:

- `DatabaseConfig.kt` — el `FlywayMigrationStrategy` que definía fue
  removido en SB4. La estrategia que tenía es la default de Spring
  Boot cuando `spring.flyway.enabled=true`.

#### Toolchain Gradle 9 (descubierto en Render, no localmente)

Java 25 (que viene con `graalvm-community:25`) **requiere Gradle 9.1+**.
Gradle 8.14.3 no entiende Java 25 y falla con un mensaje críptico:
`* What went wrong: 25.0.2`. Esto solo se detectó cuando el deploy en
Render intentó compilar — localmente teníamos Java 21, donde Gradle
8.14.3 era feliz.

Pero Gradle 9 a su vez removió `JvmVendorSpec.IBM_SEMERU` (campo de la
toolchain API). Dos plugins lo referenciaban:

1. **GraalVM Native Build Tools `0.11.5`** → bumped a `1.1.0`
   (configurado en `build.gradle.kts`).
2. **foojay-resolver-convention `0.10.0`** → bumped a `1.0.0`
   (configurado en `settings.gradle.kts` — fácil de pasar por alto
   cuando uno revisa solo `build.gradle.kts`).

El changelog de foojay 1.0.0 lo dice literalmente:
> *"Removed direct references to deprecated JvmVendorSpec.IBM_SEMERU,
> to prepare for Gradle 9 compatibility."*

**Lección**: cuando bumeás Gradle a 9, grep el classpath de plugins
por `IBM_SEMERU`. Cualquier plugin pre-Q2 2025 es sospechoso.

#### Resultado medido en Render (post-Round 3)

```
ColdStart timeToReady=14308ms phases={
  jvmToFrameworkMs=13,
  environmentMs=193,
  contextInitMs=9,
  beanDefinitionsMs=0,
  singletonsMs=14001,    ← Hibernate EMF (4790) + 9211 ms repartidos en sub-segundos
  postSingletonsMs=91,
  runnersMs=1
}

Slow bean init log:
  - tomcatServletWebServerFactory: 202 ms
  - correlationIdFilter: 391 ms
  - entityManagerFactory: 4790 ms  ← Hibernate metamodel de 23 entities (irreducible)
  - jpaUserRepository: 586 ms      ← otro repo con varios @Query

NO aparecen (todos sub-200 ms ahora):
  - jpaSongRepository (era 13890 ms)
  - jpaRefreshTokenRepository (era 793 ms)
  - mvcHandlerMappingIntrospector (era 1202 ms)
```

**Tests**: 607 tests, 0 fallos. AOT processing exitoso (22
`*Impl__AotRepository.java` generados).

---

### Notas sobre native image + Spring Data JPA AOT (histórico, ahora aplicado)

> ⚠️ **Esta nota era pre-Round 3.** El proyecto YA está en SB4.0.6 con
> AOT repositories habilitadas. Se mantiene como referencia histórica
> y para entender por qué se decidió hacer la migración mayor.

Spring Data JPA 4.0+ tiene **AOT-generated repository implementations**
que mueven el costo de query parsing de runtime a build time. Spring
Boot 3.5.5 incluía Spring Data JPA 3.3.x donde esa feature **NO está
disponible** (aparece como estable en 4.0).

```yaml
# Equivalent in YAML form (we set it via build.gradle.kts instead so
# it applies to processAot, not just runtime — see Round 3 above)
spring:
  aot:
    repositories:
      enabled: true
```

---

## Tests de regresión (pinning the contract)

Cada optimización tiene un test que la pin. **No los aflojes.** Si un
test falla tras un cambio tuyo, lo más probable es que tu cambio
revertió silenciosamente una optimización.

| Test                                                    | Qué pin                                                       |
| ------------------------------------------------------- | ------------------------------------------------------------- |
| `ProdProfileColdStartConfigTest` (10 casos)             | Defaults del YAML prod: hikari, flyway, dialect, ddl-auto, **bootstrap-mode: lazy**, **observations.spring.security disabled** |
| `BaseProfileColdStartConfigTest` (2 casos)              | Flyway `connect-retries=1`, `connect-retries-interval=5`      |
| `ProdProfileContextLoadsWithoutDbSmokeTest` (3 casos)   | **Smoke**: contexto prod arranca con DB inalcanzable          |
| `FirebaseConfigTest` (+2 casos)                         | `@Lazy` en `firebaseApp()` y `firebaseMessaging()`            |
| `FirebasePushGatewayTest > cold start safeguard`        | `ObjectProvider<FirebaseMessaging>` (no `@Lazy`/CGLIB) en el constructor |
| `MailConfigValidatorTest` (7 casos)                     | Prod NO debe lanzar ante config faltante                      |
| `StartupTimestampRecorderTest` (6 casos)                | Telemetría de fases: bindings a eventos, captura once-only, `phases` vacío hasta que ambos endpoints existan, `afterSingletonsInstantiated` cierra `singletonsMs` |
| `SlowBeanInitLoggerTest` (5 casos)                      | `BeanPostProcessor` no muta el bean, solo registra los lentos, prioridad correcta para cubrir AOP, no colisiona nombres |
| `HealthControllerTest` (+3 casos)                       | Bloque `startup` siempre presente, incluye `phases` + `slowBeans` + `slowBeanThresholdMs`, **bloque `databaseWarmup` siempre presente** |
| `DatabaseWarmupRunnerTest` (7 casos)                    | **Async DB warmup**: estado machine, single-thread executor, fail-silent, idempotencia, timing capturado en `durationMs` |

Total cobertura: ~28 tests específicos de cold start. Ejecutar:

```bash
./gradlew :api:test --tests "*ColdStart*" --tests "*StartupTimestamp*" \
                    --tests "*FirebaseConfig*" --tests "*FirebasePushGateway*" \
                    --tests "*DatabaseWarmup*" \
  && ./gradlew :infrastructure:test --tests "*MailConfigValidator*"
```

---

## Smoke test: cómo prueba que NO se abre conexión

`ProdProfileContextLoadsWithoutDbSmokeTest` carga el contexto de Spring
con perfil `prod` activo y `DATABASE_URL=jdbc:postgresql://localhost:1/worshiphub`
— un TCP black hole. Si cualquier componente intenta abrir conexión
durante el context refresh, la conexión rebota inmediatamente
(`Connection refused`) o cuelga hasta `connection-timeout` (10 s) y la
app falla al arrancar.

El test pasa, lo que demuestra empíricamente que:

1. Hikari no pre-warmea (`minimum-idle: 0`, `init-fail-timeout: -1`).
2. Hibernate construye `SessionFactory` sin probar la DB
   (`allow_jdbc_metadata_access: false` + dialect explícito).
3. Flyway no corre (`enabled: false` por default).
4. Firebase no se inicializa (`@Lazy` en bean + `ObjectProvider` en el consumer).
5. `MailConfigValidator` no aborta startup.
6. Ningún `@Scheduled` / `@PostConstruct` / `CommandLineRunner` toca DB
   en los primeros segundos.

Si alguno de estos invariantes se rompe, el smoke test falla de forma
ruidosa con un stack trace que identifica el componente culpable.

---

## Cosas que **deliberadamente** NO se hicieron

- **`spring.main.lazy-initialization=true` global**. Rompe `@Scheduled`,
  `@EventListener`, beans que dependen de inicialización ordenada. El
  ahorro no compensa la fragilidad. En su lugar, lazy quirúrgico solo
  donde aporta (Firebase).

- **`@Lazy FirebaseMessaging?` en el constructor de
  `FirebasePushGateway`**. La primera implementación lo hizo así y
  pasó todos los tests JVM. **En native image crasheó al startup** con
  `Could not generate CGLIB subclass of FirebaseMessaging`. La
  solución correcta es `ObjectProvider<FirebaseMessaging>`. Ver
  [optimización #1](#1-lazy-initialization-de-firebase) para detalles
  y el test que previene la regresión.

- ~~**Connection-pool warming asíncrono**~~. Originalmente rechazado:
  *"agrega complejidad y la primera request ya obtiene un mensaje
  rápido tras el wake-up de 5–10 s; total <15 s, todavía aceptable"*.
  **Re-evaluado en Round 4 y aplicado** tras medir un cold start
  end-to-end de 32 s desde el cliente (12.6 s server-side + ~10 s
  Neon wake-up + ~3 s container scheduling + Render edge proxy).
  Ver [Round 4](#round-4-async-db-warmup) más abajo. La complejidad
  resultó ser baja (un solo `@EventListener` con un thread daemon)
  y la ganancia user-perceived fue alta (~10 s menos en la primera
  request real).

- **Cache de `applicationReadyAt` en disco**. El timestamp se pierde al
  morir el container. No vale la pena persistirlo: lo que interesa es
  el delta `jvmStartedAt → applicationReadyAt` del proceso vigente.

- **Health check de Render apuntando a `/actuator/health`**. Tentador
  porque es "el estándar Spring Boot", pero incluye un health
  indicator de DB que rompe el cold start. `/api/v1/health` propio es
  el path correcto.

### Optimizaciones rechazadas en Round 3 (post-medición)

Tras llegar a 14 s medidos, evaluamos estas optimizaciones para bajar
a ~10 s. Todas con ratio costo/beneficio malo en este contexto:

- **Hibernate static metamodel generator** (annotation processor que
  pre-genera el metamodel en build time). Podría ahorrar ~2–3 s del
  `entityManagerFactory` boot, pero requiere setup de annotation
  processing en los 4 módulos Gradle, mantenimiento extra ante cada
  cambio de entity, y bumps de Hibernate pueden romper la generación.
  Evaluado y descartado: 4 segundos de cold start ocasional vs
  fricción de desarrollo permanente.

- **Migrar entities raramente usadas a Spring Data JDBC**. Entities
  como `ErrorLog`, `EmailVerificationToken`, `PasswordResetToken` no
  necesitan el aggregate semantics de JPA — solo lectura/escritura
  simple. Pasarlas a Spring Data JDBC sacaría ~1–2 s del
  `entityManagerFactory`. Evaluado y descartado: refactor grande con
  riesgo de bugs sutiles para ganancia marginal.

- **Project CRaC / CDS / Leyden**. Spring Boot 4 soporta Coordinated
  Restore at Checkpoint como preview. Promete reducir cold start
  30–50 % adicional, pero sigue siendo experimental, requiere
  cambios en runtime de Render (no soporta CRaC en free tier al
  momento de escribir esto), y tiene caveats de seguridad
  (snapshot puede contener secretos en memoria). Re-evaluar cuando
  CRaC sea estable.

- **Reducir entities @ManyToMany de Song**. La causa real de los
  13.9 s originales de `jpaSongRepository`. Las asociaciones
  many-to-many son costosas porque cada `@Query` HQL las introspecta.
  Pero modelar `song_categories` y `song_tags` como entidades
  intermedias tipo `@OneToMany` no es trivial — afecta queries
  existentes y el setlist auto-generation algorithm. Con AOT
  repositories de SB4, ese costo desaparece sin tocar el modelo, lo
  que es estrictamente mejor.

---

## Resultado real medido en cold start (post-Round 3)

Verificado en producción Render free tier el 2026-05-21:

```
ColdStart timeToReady=14308ms phases={
  jvmToFrameworkMs=13,
  environmentMs=193,
  contextInitMs=9,
  beanDefinitionsMs=0,
  singletonsMs=14001,
  postSingletonsMs=91,
  runnersMs=1
}
```

Desglose conceptual:

```
Container scheduling                         ~0–1 s   (fuera de nuestro control)
Native binary start                          ~0 s     (GraalVM AOT-compiled)
Spring context refresh (singletonsMs)
  ├─ Hibernate EntityManagerFactory          ~4.8 s   (irreducible — 23 entities)
  ├─ Tomcat + filter chain                   ~0.6 s   (Tomcat boot)
  ├─ jpaUserRepository                       ~0.6 s   (sigue eager)
  └─ Otros singletons (sub-200 ms cada uno)  ~8.0 s   (suma de 50+ beans)
─────────────────────────────────────────────────────
/api/v1/health responde 200 UP               ~14 s    total
```

A partir de ahí, la **primera request real** paga el wake-up de Neon
(~5–10 s) y el primer push notification paga el init de Firebase
(~2–5 s), ambos en thread aislado del health probe.

**Floor teórico estimado**: ~10 s. Bajar de 14 s a 10 s requeriría
optimizaciones con ratio costo/beneficio malo (Hibernate static
metamodel processor, eliminar entities, CDS/Project Leyden), todas
listadas en [Cosas que deliberadamente NO se hicieron](#cosas-que-deliberadamente-no-se-hicieron).

---

## Round 4: Async DB warmup

### Motivación

Después de Round 3 medimos un cold start end-to-end desde el cliente
de **~32 s** mientras el servidor reportaba `timeToReadyMs=12608`.
La diferencia (~20 s) se desglosa así:

```
Cliente envía request                          t = 0
  ├─ Render edge: container scheduling          ~3 s
  ├─ JVM start + Spring context refresh        ~12.6 s   (timeToReadyMs)
  ├─ /api/v1/health responde 200 UP             ↑ aquí Render marca "live"
  ├─ Cliente envía PRIMERA request real        +0 s
  ├─ Hikari abre primera conexión TCP          
  │   └─ Neon wake-up de cold storage          ~5–10 s   ← ESTO atacamos
  ├─ DispatcherServlet lazy-init                ~0.5 s
  └─ Response                                   t ≈ 32 s total
```

El `timeToReadyMs` server-side ya está en su floor (~10 s irreducible).
Pero el componente **wake-up de Neon** (que aporta hasta 10 s a la
primera request real) **sí se puede paralelizar** con el startup de
Spring: en lugar de esperar a que llegue el primer request para abrir
la conexión, la abrimos en background apenas Spring está ready.

### Implementación

`DatabaseWarmupRunner` (`api/src/main/kotlin/com/worshiphub/api/health/`):

- `@EventListener(ApplicationReadyEvent::class)` — se dispara DESPUÉS
  del context refresh, así que **no afecta `timeToReadyMs`** ni el
  health probe inicial de Render.
- Ejecuta `SELECT 1` en un **executor de un solo thread daemon**
  dedicado. No usa el thread pool de requests (Tomcat) ni el de
  `@Async` por defecto: aislamiento total.
- Estado expuesto vía `AtomicReference<WarmupState>`:
  `NOT_STARTED → IN_PROGRESS → COMPLETED | FAILED`. Thread-safe sin
  locks.
- **Fail-silent**: si Neon no responde o la query falla, loguea
  `ERROR` con el throwable y deja el estado en `FAILED`. La app
  sigue funcionando — la primera request real pagará el wake-up
  como antes (degradación graceful al comportamiento previo).
- Inyección de `DataSource` vía `ObjectProvider` para que el bean
  pueda existir aunque `DataSource` no esté disponible (slices de
  test sin JDBC). Si falta, el runner se desactiva con un log INFO.

`HealthController` ahora expone un bloque nuevo en `/api/v1/health`:

```json
{
  "status": "UP",
  "startup": { ... },
  "databaseWarmup": {
    "warmedUp": true,
    "warmedUpAt": "2026-05-21T13:14:08.123Z",
    "durationMs": 4821
  }
}
```

Esto sirve para:
- Validar en producción que el warmup efectivamente completa.
- Medir cuánto tarda Neon en despertar (`durationMs`).
- Detectar regresiones (si `warmedUp=false` 30 s después del start,
  algo está roto).

### Configuración

Activado por defecto en todos los profiles. Para desactivarlo
(útil en tests con TCP black hole o entornos sin DB):

```yaml
worshiphub:
  startup:
    db-warmup:
      enabled: false
```

### Tests

- `DatabaseWarmupRunnerTest` (7 tests, JUnit 5 + Mockk): cubre los
  cuatro estados, el aislamiento de threads, el comportamiento
  fail-silent y la idempotencia de `onApplicationReady`.
- `HealthControllerTest` actualizado: el slice `@WebMvcTest` ahora
  necesita un mock de `DatabaseWarmupRunner` (provisto por
  `DatabaseWarmupTestConfig` con `relaxed = true` porque el slice
  dispara `ApplicationReadyEvent` durante el refresh).
- `ProdProfileContextLoadsWithoutDbSmokeTest` agrega
  `worshiphub.startup.db-warmup.enabled=false` para evitar que el
  runner intente conectar al TCP black hole (limpieza de logs, no
  un fallo real — el runner es fail-silent).

### Resultado esperado

Cliente debería ver la primera request real bajar de ~32 s a
**~15–18 s** (el wake-up de Neon ya completó, o está casi
completo, mientras Spring estaba arrancando). Pendiente de medir
en producción tras deploy.

### Por qué no hicimos esto antes

En Round 3 dijimos: *"agrega complejidad y la primera request ya
obtiene un mensaje rápido tras el wake-up de 5–10 s; total <15 s,
todavía aceptable"*. Esa lectura era incorrecta porque:

1. La medición server-side (12.6 s) ocultaba los ~20 s adicionales
   que ve el cliente en el path completo (Render scheduling +
   Neon wake-up + edge proxy).
2. Una vez que medimos client-side el verdadero "32 s desde curl",
   atacar el wake-up de Neon pasó a ser el ROI más alto disponible
   (10 s ganados con ~150 LOC).
3. La complejidad real resultó ser baja: un `@EventListener`,
   un `Executors.newSingleThreadExecutor`, un `AtomicReference`.
   Ningún thread pool nuevo de tamaño N, ningún scheduler.

---

## Si necesitás revertir algún cambio

1. Identificá qué optimización querés deshacer.
2. Mirá la fila correspondiente en
   [Tests de regresión](#tests-de-regresión-pinning-the-contract).
3. Editá el código **y** el test que lo pin, en el mismo commit, con
   un mensaje que justifique el trade-off.
4. Documentá el cambio acá (sección
   [Cambios implementados](#cambios-implementados)) para que la próxima
   persona no vuelva a "optimizar" lo que conscientemente revertiste.

Aflojar un test sin tocar el documento es una receta para que esta
historia se repita.
