# Estructura del Proyecto WorshipHub API

## 📁 Estructura Organizada

```
worship_hub_api/
│
├── 🎯 worshiphub.bat              # LAUNCHER PRINCIPAL (Windows)
├── 🎯 worshiphub.sh               # LAUNCHER PRINCIPAL (Linux/Mac)
│
├── 📖 README.md                   # Documentación principal
├── 📖 WORSHIPHUB_DOCUMENTATION.md # Documentación técnica completa
│
├── 🐳 docker-compose.yml          # Configuración Docker
├── 🐳 Dockerfile                  # Imagen Docker JVM
├── 🐳 Dockerfile.native           # Imagen Docker Native
├── 📄 init-db.sql                 # Script de inicialización DB
│
├── 🔧 build.gradle.kts            # Configuración Gradle raíz
├── 🔧 settings.gradle.kts         # Configuración módulos Gradle
├── 🔧 gradlew                     # Gradle Wrapper (Linux/Mac)
├── 🔧 gradlew.bat                 # Gradle Wrapper (Windows)
│
├── ☁️ cloudbuild.yaml             # Google Cloud Build
├── ☁️ cloudbuild-native.yaml      # Cloud Build Native
├── 🚀 build-native-local.bat      # Build nativo local
│
├── 📂 scripts/                    # SCRIPTS ORGANIZADOS
│   ├── README.md                  # Documentación de scripts
│   ├── PLATFORM_SUPPORT.md        # Soporte multiplataforma
│   │
│   ├── start-worshiphub.bat       # Menú principal (Windows)
│   ├── start-worshiphub.sh        # Menú principal (Linux/Mac)
│   │
│   ├── start-database.bat         # Iniciar Docker (Windows)
│   ├── start-database.sh          # Iniciar Docker (Linux/Mac)
│   │
│   ├── check-system.bat           # Verificar sistema (Windows)
│   ├── check-system.sh            # Verificar sistema (Linux/Mac)
│   │
│   ├── fix-ports.bat              # Reparar puertos (Windows)
│   │
│   ├── mailpit-manager.bat        # Gestor Mailpit (Windows)
│   └── db-manager.bat             # Gestor DB (Windows)
│
├── 📂 api/                        # Módulo API (Spring Boot)
│   ├── src/                       # Código fuente
│   │   ├── main/
│   │   │   ├── kotlin/            # Código Kotlin
│   │   │   └── resources/         # Configuraciones
│   │   └── test/                  # Tests
│   │
│   ├── scripts/                   # Scripts de la API
│   │   ├── README.md
│   │   ├── start-local.bat        # Perfil local (Windows)
│   │   ├── start-local.sh         # Perfil local (Linux/Mac)
│   │   ├── start-h2.bat           # Perfil H2 (Windows)
│   │   ├── start-h2.sh            # Perfil H2 (Linux/Mac)
│   │   └── setup-database.sql     # Setup DB
│   │
│   ├── logs/                      # Logs de la aplicación
│   ├── .env.local                 # Variables de entorno local
│   ├── .env.prod.example          # Ejemplo para producción
│   └── build.gradle.kts           # Configuración Gradle
│
├── 📂 application/                # Módulo Application (Use Cases)
│   ├── src/
│   │   ├── main/kotlin/           # Services, Commands
│   │   └── test/                  # Tests
│   └── build.gradle.kts
│
├── 📂 domain/                     # Módulo Domain (Entities, Business Logic)
│   ├── src/
│   │   ├── main/kotlin/           # Entities, Value Objects, Domain Services
│   │   └── test/                  # Tests
│   └── build.gradle.kts
│
├── 📂 infrastructure/             # Módulo Infrastructure (JPA, Repositories)
│   ├── src/
│   │   └── main/kotlin/           # JPA Entities, Repository Implementations
│   └── build.gradle.kts
│
├── 📂 data/                       # Datos persistentes
│   └── db/                        # Datos de PostgreSQL (generado)
│
├── 📂 gradle/                     # Gradle wrapper
│   └── wrapper/
│
└── 📂 .git/                       # Control de versiones Git
```

## 🎯 Puntos de Entrada

### Para Usuarios

```bash
# Windows
worshiphub.bat

# Linux/Mac
./worshiphub.sh
```

### Para Desarrolladores

```bash
# Verificar sistema
scripts/check-system.bat  # Windows
./scripts/check-system.sh # Linux/Mac

# Iniciar servicios Docker
scripts/start-database.bat  # Windows
./scripts/start-database.sh # Linux/Mac

# Iniciar API directamente
cd api/scripts
start-local.bat  # Windows
./start-local.sh # Linux/Mac
```

## 📚 Documentación

| Archivo | Propósito | Audiencia |
|---------|-----------|-----------|
| `START_HERE.md` | Guía de inicio principal | Nuevos usuarios |
| `README.md` | Documentación del proyecto | Todos |
| `QUICK_START.md` | Inicio rápido | Desarrolladores |
| `SCRIPTS_GUIDE.md` | Guía detallada de scripts | Desarrolladores |
| `SCRIPTS_SUMMARY.md` | Resumen del sistema | Mantenedores |
| `WORSHIPHUB_DOCUMENTATION.md` | Documentación técnica completa | Arquitectos |
| `scripts/README.md` | Documentación de scripts | Desarrolladores |
| `scripts/PLATFORM_SUPPORT.md` | Soporte multiplataforma | DevOps |
| `api/scripts/README.md` | Scripts de la API | Desarrolladores |

## 🏗️ Arquitectura de Módulos

```
┌─────────────────────────────────────────┐
│              API Module                 │
│  (Controllers, Security, Config)        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Application Module              │
│  (Use Cases, Services, Commands)        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│           Domain Module                 │
│  (Entities, Business Logic)             │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│       Infrastructure Module             │
│  (JPA, Repositories, External)          │
└─────────────────────────────────────────┘
```

## 🔧 Scripts por Categoría

### Launchers Principales
- `worshiphub.bat` / `worshiphub.sh` - Punto de entrada único

### Scripts de Sistema
- `scripts/check-system.*` - Verificación de requisitos
- `scripts/fix-ports.bat` - Reparar puertos ocupados

### Scripts de Docker
- `scripts/start-database.*` - Iniciar PostgreSQL + Mailpit
- `scripts/db-manager.bat` - Gestor de base de datos
- `scripts/mailpit-manager.bat` - Gestor de Mailpit

### Scripts de Aplicación
- `api/scripts/start-local.*` - Perfil local (PostgreSQL)
- `api/scripts/start-h2.*` - Perfil H2 (memoria)

### Scripts de Menú
- `scripts/start-worshiphub.*` - Menú interactivo principal

## 🌍 Soporte Multiplataforma

| Plataforma | Scripts | Estado |
|------------|---------|--------|
| Windows 10/11 | `.bat` | ✅ Completo |
| macOS | `.sh` | ✅ Completo |
| Linux (Ubuntu/Debian) | `.sh` | ✅ Completo |
| Linux (Fedora/RHEL) | `.sh` | ✅ Completo |
| WSL2 | `.sh` | ✅ Completo |

## 📊 Estadísticas del Proyecto

- **Módulos**: 4 (api, application, domain, infrastructure)
- **Scripts**: 16 (8 Windows, 8 Linux/Mac)
- **Documentos**: 8 guías completas
- **Endpoints**: 60+ REST endpoints
- **Líneas de código**: ~15,000+
- **Tests**: 30+ archivos de test

## 🎯 Flujo de Trabajo Recomendado

### Primera Vez
```bash
1. worshiphub.bat/sh
2. Opción 1 (Desarrollo Local)
3. Esperar a que inicie
4. Abrir http://localhost:9090/swagger-ui.html
```

### Desarrollo Diario
```bash
1. worshiphub.bat/sh
2. Opción 1 (Desarrollo Local)
```

### Desarrollo Rápido
```bash
1. worshiphub.bat/sh
2. Opción 2 (H2 en memoria)
```

### Problemas de Puertos
```bash
1. worshiphub.bat/sh
2. Opción A (Reparar puertos)
3. Opción 5 (Todos los puertos)
```

## 🔒 Archivos Importantes

### Configuración
- `docker-compose.yml` - Servicios Docker
- `build.gradle.kts` - Configuración Gradle
- `api/src/main/resources/application*.yml` - Perfiles Spring

### Datos
- `data/db/` - Datos PostgreSQL (no versionar)
- `api/logs/` - Logs de aplicación (no versionar)

### Git
- `.gitignore` - Archivos ignorados
- `.git/` - Repositorio Git

## 💡 Tips

1. **Usa el launcher principal** (`worshiphub.*`) para todo
2. **Lee START_HERE.md** antes de empezar
3. **Verifica requisitos** con `check-system.*`
4. **Usa perfil local** para desarrollo completo
5. **Usa perfil H2** para pruebas rápidas
6. **Revisa logs** en `api/logs/worshiphub.log`
7. **Usa Swagger** para probar endpoints
8. **Usa Mailpit** para ver emails

---

**Estructura limpia, organizada y lista para desarrollo profesional! 🚀**
