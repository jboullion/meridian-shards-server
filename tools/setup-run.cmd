@echo off
rem Prepares run\shards, our run folder (git-ignored by upstream's run/* rule).
rem blakserv runs from there with ..\server\blakserv.exe; it reads the build output
rem (loadkod, rsc) from run\server and keeps its own config, saves and logs.
rem Safe to run again: it refreshes the config and MOTD and never touches savegames.
setlocal
set ROOT=%~dp0..
set RUN=%ROOT%\run\shards
for %%d in (memmap savegame channel) do (
  if not exist "%RUN%\%%d\" mkdir "%RUN%\%%d" || exit /b 1
)
copy /Y "%ROOT%\config\blakserv.cfg" "%RUN%\blakserv.cfg" >nul || exit /b 1
rem blakserv moves motd.txt into memmap\ at startup or on "reload motd"
copy /Y "%ROOT%\config\motd.txt" "%RUN%\motd.txt" >nul || exit /b 1
if not exist "%RUN%\packages.txt" copy "%ROOT%\run\server\packages.txt" "%RUN%\packages.txt" >nul
rem The IP ban list (blakserv/loadall.c:41); an empty one avoids a startup error
if not exist "%RUN%\banned.txt" type nul > "%RUN%\banned.txt"
if not exist "%ROOT%\run\server\blakserv.exe" echo Note: run\server\blakserv.exe is missing; build with "nmake Bserver Bkod" first.
echo Run folder ready: %RUN%
echo Start the server with:  cd /d "%RUN%" ^&^& ..\server\blakserv.exe
