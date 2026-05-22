@echo off
REM ============================================
REM  WorshipHub - Dev Launcher (2 terminales)
REM ============================================
REM
REM Abre dos terminales:
REM   1. Backend local: PostgreSQL + Mailpit (docker-compose) + API Spring Boot
REM   2. Frontend Flutter Web (Chrome)
REM
REM Uso: doble click en este archivo, o desde CMD: start-dev.bat
REM

setlocal

set "ROOT=%~dp0"
set "API_DIR=%ROOT%worship_hub_api"
set "UI_DIR=%ROOT%worship_hub_ui"
set "API_SCRIPTS_DIR=%API_DIR%\api\scripts"

echo.
echo ========================================
echo   WorshipHub - Dev Launcher
echo ========================================
echo.
echo Raiz del proyecto: %ROOT%
echo.

REM ---- Validaciones basicas ----
if not exist "%API_DIR%\docker-compose.yml" (
    echo [ERROR] No se encontro %API_DIR%\docker-compose.yml
    pause
    exit /b 1
)
if not exist "%UI_DIR%\pubspec.yaml" (
    echo [ERROR] No se encontro %UI_DIR%\pubspec.yaml
    pause
    exit /b 1
)
if not exist "%API_SCRIPTS_DIR%\start-local.bat" (
    echo [ERROR] No se encontro %API_SCRIPTS_DIR%\start-local.bat
    pause
    exit /b 1
)

REM ---- Verificar Docker ----
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker no esta corriendo. Inicia Docker Desktop y vuelve a intentarlo.
    pause
    exit /b 1
)

echo [1/2] Iniciando servicios Docker (PostgreSQL + Mailpit)...
REM IMPORTANT: only start `db` and `mailpit` explicitly. The
REM `docker-compose.yml` at the root of the API also declares a
REM `backend` service that builds the GraalVM native image and
REM listens on the same host port 9090 we want Gradle (bootRun) to
REM claim from `start-local.bat`. If we let compose pick services by
REM default it brings `backend` up too, which either (a) steals port
REM 9090 so Gradle fails, or (b) loses the port race to Gradle and
REM keeps rebuilding in the background — both break dev mode.
REM
REM For a native-backend-in-docker flow use `worship_hub_api\deploy-local.bat`
REM instead; this launcher is specifically for "hot-reload + debug"
REM development with the API running straight from Gradle.
pushd "%API_DIR%"
docker-compose up -d db mailpit
if errorlevel 1 (
    echo.
    echo [ERROR] Fallo docker-compose up -d db mailpit
    popd
    pause
    exit /b 1
)
popd

echo.
echo Esperando a que PostgreSQL este listo en el puerto 5442...
set /a _tries=0
:wait_db
set /a _tries+=1
netstat -an | findstr ":5442 " >nul 2>&1
if not errorlevel 1 goto db_ready
if %_tries% GEQ 30 (
    echo [ADVERTENCIA] PostgreSQL no respondio en 30s. Continuando de todos modos...
    goto db_ready
)
timeout /t 1 /nobreak >nul
goto wait_db

:db_ready
echo [OK] PostgreSQL listo.
echo.
echo URLs de servicios de desarrollo:
echo   API       : http://localhost:9090/api/v1
echo   Swagger   : http://localhost:9090/swagger-ui.html
echo   Mailpit   : http://localhost:8025
echo   Postgres  : localhost:5442 (worshiphub / postgres / postgres)
echo.

echo [2/2] Abriendo terminales de Backend y Frontend...
echo.

REM ---- Terminal 1: Backend (Spring Boot en modo local) ----
REM Usamos /D para fijar el working directory y evitar comillas anidadas.
start "WorshipHub Backend" /D "%API_SCRIPTS_DIR%" cmd /k start-local.bat

REM Pequena espera para que el backend inicie antes de lanzar el frontend
timeout /t 3 /nobreak >nul

REM ---- Terminal 2: Frontend (Flutter Web en Chrome) ----
start "WorshipHub Frontend" /D "%UI_DIR%" cmd /k flutter run -d chrome --dart-define=ENV=development

echo.
echo ========================================
echo  Terminales lanzadas
echo ========================================
echo.
echo   - Backend : ventana "WorshipHub Backend"
echo   - Frontend: ventana "WorshipHub Frontend"
echo.
echo Para detener servicios Docker despues:
echo   cd worship_hub_api
echo   docker-compose down
echo.
echo Esta ventana se cerrara en 5 segundos...
timeout /t 5 /nobreak >nul
endlocal
exit /b 0
