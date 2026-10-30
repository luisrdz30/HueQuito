@echo off
REM Abre HueQuito en Chrome en modo desarrollo
cd /d "%~dp0"
set MAPS_KEY=
for /f "usebackq tokens=1,* delims==" %%a in ("android\local.properties") do if "%%a"=="MAPS_API_KEY" set MAPS_KEY=%%b
call flutter pub get
call flutter run -d chrome --dart-define=MAPS_API_KEY=%MAPS_KEY%
pause
