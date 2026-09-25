@echo off
rem Voce (J1) contra o bot (J2). Argumentos extras vao para o jogo: JogarVsBot.bat --p1 pesado --p2 leve
call "%~dp0Jogar.bat" --cpu %*
