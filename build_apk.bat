@echo off
REM Compila el APK y el App Bundle con la clave de rutas (sin ella, las rutas salen en linea recta)
cd /d "%~dp0"
set MAPS_KEY=
for /f "usebackq tokens=1,* delims==" %%a in ("android\local.properties") do if "%%a"=="MAPS_API_KEY" set MAPS_KEY=%%b
if "%MAPS_KEY%"=="" (echo ERROR: falta MAPS_API_KEY en android\local.properties & pause & exit /b 1)
call flutter build apk --release --dart-define=MAPS_API_KEY=%MAPS_KEY%
if errorlevel 1 (pause & exit /b 1)
call flutter build appbundle --release --dart-define=MAPS_API_KEY=%MAPS_KEY%
if errorlevel 1 (pause & exit /b 1)
echo LISTO: build\app\outputs\flutter-apk\app-release.apk y build\app\outputs\bundle\release\app-release.aab
pause
