# Compilación de APK por Entorno — WorshipHub

Guía completa para compilar e instalar APKs de WorshipHub en dispositivos Android, tanto para pruebas locales (backend Docker) como para producción (backend en internet).

## Prerrequisitos

Antes de compilar un APK, asegúrate de tener instalado y configurado:

1. **Flutter SDK** — Instalado y disponible en el PATH del sistema.
   - Descarga: https://docs.flutter.dev/get-started/install
   - Verifica con: `flutter --version`

2. **Android SDK** — Instalado via Android Studio o de forma independiente.
   - Verifica con: `flutter doctor` (debe mostrar Android toolchain sin errores)

3. **Dispositivo Android o emulador** — Para instalar y probar el APK generado.
   - Dispositivo físico: habilitar "Depuración USB" en Opciones de desarrollador
   - Emulador: configurar desde Android Studio (AVD Manager)
   - Verifica con: `flutter devices`

4. **Docker Desktop** (solo para pruebas locales) — Para ejecutar el backend nativo.
   - Descarga: https://www.docker.com/products/docker-desktop

## Flujo para Pruebas Locales (Backend Docker)

Este flujo permite probar la app en un dispositivo físico Android conectado al backend Docker corriendo en tu máquina.

### Paso 1: Levantar el backend Docker

Desde la carpeta `worship_hub_api`, ejecuta el script de despliegue local:

```bat
cd worship_hub_api
deploy-local.bat
```

Esto levanta PostgreSQL, Mailpit y el backend nativo GraalVM. Espera a que los servicios estén disponibles:

- API: http://localhost:9090
- Health check: http://localhost:9090/api/v1/health

### Paso 2: Compilar el APK local

Desde la carpeta `worship_hub_ui`, usa `local-auto` para que el script detecte tu IP automáticamente:

```bat
cd worship_hub_ui
scripts\build-apk.bat local-auto
```

El script detecta la IP de tu adaptador WiFi/Ethernet y compila el APK apuntando a esa dirección. Por ejemplo, si tu IP es `192.168.1.100`, el APK apuntará a `http://192.168.1.100:9090`.

> **Nota:** Tu dispositivo Android debe estar conectado a la misma red WiFi que tu máquina de desarrollo.

**Alternativa manual:** Si la detección automática no funciona o quieres usar una IP específica:

```bat
scripts\build-apk.bat local 192.168.1.100
```

### Paso 4: Instalar el APK en el dispositivo

Con el dispositivo conectado por USB:

```bat
flutter install
```

O copia manualmente el APK desde:

```
build\app\outputs\flutter-apk\app-release.apk
```

### Verificación

1. Abre la app en el dispositivo
2. Verifica que se conecta al backend local (puedes ver los logs del backend con `deploy-local.bat logs`)
3. Prueba login, navegación y funcionalidades que requieran el backend

## Flujo para Pruebas en Producción (Backend en Internet)

Este flujo genera un APK que apunta al backend desplegado en un servidor público.

### Paso 1: Verificar el backend de producción

Confirma que el backend está disponible accediendo al health check:

```
https://api.worshiphub.com/api/v1/health
```

Si usas un dominio personalizado, verifica su URL correspondiente.

### Paso 2: Compilar el APK de producción

Desde la carpeta `worship_hub_ui`:

```bat
scripts\build-apk.bat production
```

Esto ejecuta internamente:

```bat
flutter build apk --release --dart-define=ENV=production --dart-define=API_HOST=api.worshiphub.com
```

El APK generado apuntará a `https://api.worshiphub.com` usando conexiones seguras (HTTPS/WSS).

Para usar un dominio personalizado:

```bat
scripts\build-apk.bat production mi-servidor.com
```

### Paso 3: Instalar el APK

Con el dispositivo conectado por USB:

```bat
flutter install
```

O distribuye el APK desde:

```
build\app\outputs\flutter-apk\app-release.apk
```

## Referencia de Comandos

### Script `build-apk.bat`

| Comando | Descripción |
|---------|-------------|
| `scripts\build-apk.bat` | Muestra la ayuda con opciones disponibles |
| `scripts\build-apk.bat local-auto` | Detecta la IP WiFi/Ethernet y compila APK local |
| `scripts\build-apk.bat local` | Compila APK local con IP por defecto (`10.0.2.2`) |
| `scripts\build-apk.bat local <ip>` | Compila APK local con la IP especificada |
| `scripts\build-apk.bat production` | Compila APK de producción con host por defecto (`api.worshiphub.com`) |
| `scripts\build-apk.bat production <host>` | Compila APK de producción con host personalizado |

### Compilación manual con Flutter

Si prefieres ejecutar los comandos directamente sin el script:

**APK local:**

```bat
flutter build apk --dart-define=ENV=local --dart-define=API_HOST=192.168.1.100
```

**APK de producción:**

```bat
flutter build apk --release --dart-define=ENV=production --dart-define=API_HOST=api.worshiphub.com
```

**Desarrollo en emulador (comportamiento por defecto):**

```bat
flutter run
```

Sin parámetros `--dart-define`, la app usa el entorno `development` con las URLs estándar del emulador Android (`http://10.0.2.2:9090`).

### Comandos del backend Docker

| Comando | Descripción |
|---------|-------------|
| `deploy-local.bat` | Compila imagen y levanta todos los servicios |
| `deploy-local.bat up` | Levanta servicios sin recompilar |
| `deploy-local.bat down` | Detiene todos los servicios |
| `deploy-local.bat logs` | Muestra logs del backend en tiempo real |
| `deploy-local.bat rebuild` | Recompila sin caché y reinicia |
| `deploy-local.bat clean` | Limpia volúmenes, borra datos y reinicia desde cero |

## Cómo Obtener la IP Local en Windows

Ejecuta `ipconfig` en una terminal (CMD o PowerShell):

```bat
ipconfig
```

Busca la sección correspondiente a tu conexión de red activa:

- **WiFi:** "Adaptador de LAN inalámbrica Wi-Fi"
- **Ethernet:** "Adaptador de Ethernet"

La línea **Dirección IPv4** contiene la IP que necesitas. Ejemplo:

```
Adaptador de LAN inalámbrica Wi-Fi:

   Estado de los medios. . . . . . . . . : medios conectados
   Sufijo DNS específico para la conexión :
   Dirección IPv4. . . . . . . . . . . . : 192.168.1.100
   Máscara de subred . . . . . . . . . . : 255.255.255.0
```

> **Tip:** Si tienes múltiples adaptadores de red, usa la IP del adaptador que está en la misma red que tu dispositivo Android.

## Resumen de Entornos

| Entorno | URL Base | WebSocket | Protocolo | Uso |
|---------|----------|-----------|-----------|-----|
| `development` | `http://10.0.2.2:9090` | `ws://10.0.2.2:9090/ws/chat` | HTTP/WS | Emulador Android (por defecto) |
| `local` | `http://{IP}:9090` | `ws://{IP}:9090/ws/chat` | HTTP/WS | Dispositivo físico → Docker local |
| `staging` | `https://staging-api.worshiphub.com` | `wss://staging-api.worshiphub.com/ws/chat` | HTTPS/WSS | Pruebas pre-producción |
| `production` | `https://{HOST}` | `wss://{HOST}/ws/chat` | HTTPS/WSS | Producción |

## Solución de Problemas

### El dispositivo no se conecta al backend local

1. Verifica que el dispositivo y la PC estén en la misma red WiFi
2. Verifica que el backend esté corriendo: `deploy-local.bat logs`
3. Prueba acceder a `http://<tu-ip>:9090/api/v1/health` desde el navegador del dispositivo
4. Revisa que el firewall de Windows no esté bloqueando el puerto 9090

### Flutter SDK no encontrado

El script muestra el error "Flutter SDK no encontrado":
- Verifica que Flutter esté instalado: https://docs.flutter.dev/get-started/install
- Verifica que Flutter esté en el PATH: ejecuta `flutter --version` en una terminal nueva

### La compilación falla

1. Ejecuta `flutter doctor` para verificar que el entorno esté correctamente configurado
2. Ejecuta `flutter clean` y vuelve a intentar la compilación
3. Verifica que las dependencias estén actualizadas: `flutter pub get`
