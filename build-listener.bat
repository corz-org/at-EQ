@echo off
setlocal
pushd "%~dp0"
if errorlevel 1 exit /b 1
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
if errorlevel 1 goto build_failed
rc /nologo /fo "Resources\@EQListener.res" "Resources\@EQListener.rc"
if errorlevel 1 goto build_failed
cl /EHsc /O2 /std:c++17 ".\@EQListener.cpp" ".\Resources\@EQListener.res" /link ole32.lib shell32.lib user32.lib /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup /OUT:"@EQListener.exe"
set "listener_build_result=%errorlevel%"
if "%listener_build_result%"=="0" (
	del /q "Resources\@EQListener.res"
	del /q "@EQListener.obj"
)
popd
exit /b %listener_build_result%

:build_failed
popd
exit /b 1
