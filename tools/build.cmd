@echo off
rem Builds with nmake from any terminal: finds Visual Studio (2026 or later) with
rem vswhere and loads its x86 compiler environment first, so no "Native Tools"
rem prompt is needed.
rem
rem   tools\build.cmd                  server and Kod (Bserver Bkod)
rem   tools\build.cmd Bclient Bmodules the Windows client and its modules
rem   tools\build.cmd RELEASE=1 Bserver
setlocal
set ROOT=%~dp0..
set VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
if not exist "%VSWHERE%" (
  echo vswhere.exe not found; install Visual Studio 2026 with "Desktop development with C++".
  exit /b 1
)
set VSDIR=
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set VSDIR=%%i
if not defined VSDIR (
  echo No Visual Studio with the C++ tools found.
  exit /b 1
)
call "%VSDIR%\VC\Auxiliary\Build\vcvars32.bat" >nul || exit /b 1
cd /d "%ROOT%"
if "%~1"=="" (
  nmake /nologo Bserver Bkod
) else (
  nmake /nologo %*
)
