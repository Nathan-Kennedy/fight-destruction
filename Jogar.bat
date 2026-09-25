@echo off
rem Fight Destruction - prototipo M1 (Godot 4.7.2). Argumentos extras vao para o jogo: Jogar.bat --cpu
set "GODOT=C:\deps\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 nao encontrado em %GODOT%
  echo Baixe em https://godotengine.org e ajuste o caminho neste arquivo.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0game" -- %*
