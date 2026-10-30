@echo off
REM Compila HueQuito para web y lo deja en build\web
cd /d "%~dp0"
set MAPS_KEY=
for /f "usebackq tokens=1,* delims==" %%a in ("android\local.properties") do if "%%a"=="MAPS_API_KEY" set MAPS_KEY=%%b
if "%MAPS_KEY%"=="" echo AVISO: no se encontro MAPS_API_KEY en android\local.properties (las rutas no se dibujaran)
call flutter config --enable-web
call flutter pub get
call flutter build web --release --dart-define=MAPS_API_KEY=%MAPS_KEY%
if errorlevel 1 (echo. & echo ERROR: revisa los mensajes de arriba & pause & exit /b 1)
copy /Y netlify.toml build\web\ >nul
echo.
echo LISTO: la app web esta en build\web
explorer build\web
pause
