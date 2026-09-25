@echo off
rem Roda a demo gravada (sequencia de referencia curta) e salva PNGs em captures\demo.
set "GODOT=C:\deps\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
"%GODOT%" --path "%~dp0game" -- --capture ../captures/demo
