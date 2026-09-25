@echo off
rem Testes headless da simulacao + autotest com bots em 4 sementes. Codigo de saida 1 se falhar.
set "GODOT=C:\deps\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
"%GODOT%" --headless --path "%~dp0game" -- --test --seconds 60
set RESULT=%ERRORLEVEL%
if "%1"=="" pause
exit /b %RESULT%
