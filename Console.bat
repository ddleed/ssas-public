@echo off

set ASPATH=%~dp0
set astmp=%ASPATH%
set ASDISK=%astmp:~1,2%
set MSYS2=D:\msys64

%ASDISK%
cd %ASPATH%

REM base env PATH
set PATH=C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0

set PATH=D:\Anaconda3;D:\Anaconda3\Scripts;%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%MSYS2%\mingw32\bin;%PATH%
set PATH=%PATH%;%ASPATH%\download\gcc-arm-none-eabi-5_4-2016q3-20160926-win32\bin

set ConEmu=%ASPATH%\download\ConEmu\ConEmu64.exe

if EXIST %ConEmu% goto prepareEnv
cd %ASPATH%\download
mkdir ConEmu
cd ConEmu
wget https://github.com/Maximus5/ConEmu/releases/download/v21.04.22/ConEmuPack.210422.7z
"C:\Program Files\7-Zip\7z.exe" x ConEmuPack.210422.7z
cd %ASPATH%

:prepareEnv
set MSYS=winsymlinks:nativestrict

start %ConEmu% -title sim-app-boot-tools ^
	-runlist -new_console:d:"%ASPATH%":t:sim ^
	^|^|^| -new_console:d:"%ASPATH%":t:app ^
	^|^|^| -new_console:d:"%ASPATH%":t:boot ^
	^|^|^| -new_console:d:"%ASPATH%/tools":t:tools

