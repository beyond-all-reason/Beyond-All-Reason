@echo off
rem Shared launcher. Usage: call _run.cmd <script-name>
rem Runs repo_tools\<script-name>.ps1 with the correct PowerShell flags,
rem then shows a success/failure message and waits for a keypress.
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0commands.ps1" %~1
set RC=%ERRORLEVEL%
echo.
if %RC% == 0 (
    echo  Done!
) else (
    echo  Something went wrong ^(exit code %RC%^). Please share the output above with the team.
)
echo.
pause
exit /b %RC%
