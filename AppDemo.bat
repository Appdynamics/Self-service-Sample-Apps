REM @echo OFF

SETLOCAL
SET APPLICATION_NAME=TestApplication
SET AXIS_PORT=8887
SET NODE_PORT=8888
SET MYSQL_PORT=8889
SET AXIS_VERSION=1.6.2
SET ANT_VERSION=1.9.4
SET NODE_VERSION=0.10.33
SET MACHINE_AGENT_VERSION=4.0.1.0
SET DATABASE_AGENT_VERSION=4.0.1.0
SET APPSERVER_AGENT_VERSION=4.0.1.0
SET SSL=false
SET ACCOUNT_NAME=
SET ACCOUNT_ACCESS_KEY=
SET CONTROLLER_ADDRESS=false
SET CONTROLLER_PORT=false
SET NOPROMPT=false
SET PROMPT_EACH_REQUEST=false
SET TIMEOUT=300 #5 Minutes
SET ARCH=$(uname -m)
SET APP_STARTED=false
SET REQUIRED_SPACE=2500000
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=32 || set OS=64

SET SCRIPT_PATH=%~dp0
SET SCRIPT_PATH=%SCRIPT_PATH:~0,-1%
SET RUN_PATH=C:\AppDynamics
SET NVM_DIR=%RUN_PATH%\.nvm
SET NVM_HOME=%NVM_DIR%
SET NVM_SYMLINK=C:\Program Files\nodejs
SET NODE_DIR=%NVM_HOME%\v%NODE_VERSION%
SET NODE_PATH=%NODE_DIR%\node_modules

mkdir "%RUN_PATH%" 2>NUL

SET ucat="%SCRIPT_PATH%\utils\unixutils\cat.exe"
SET uprintf="%SCRIPT_PATH%\utils\unixutils\printf.exe"
SET uaria="%SCRIPT_PATH%\utils\aria2\aria2c.exe"
SET uunzip="%SCRIPT_PATH%\utils\unixutils\unzip.exe"

SET node="%NODE_DIR%\node.exe"
SET npm=%node% "%NODE_PATH%\npm\bin\npm-cli.js"

if (%1)==() GOTO :startup
:GETOPTS
  if /I %1 == -h GOTO :usage
  if /I %1 == -y SET NOPROMPT=true & GOTO :GETOPTS_END
  if /I %1 == -d GOTO :removeEnvironment
  if /I %1 == -z SET PROMPT_EACH_REQUEST=true & GOTO :GETOPTS_END
  if /I %1 == -c GOTO :verifyVal
  if /I %1 == -p GOTO :verifyVal
  if /I %1 == -u GOTO :verifyVal
  if /I %1 == -k GOTO :verifyVal
  if /I %1 == -s GOTO :verifyVal
  if /I %1 == -n GOTO :verifyVal
  if /I %1 == -a GOTO :verifyVal
  if /I %1 == -m GOTO :verifyVal
  echo Invalid option: %1! & GOTO :usage
  :verifyVal
  if not (%2)==() GOTO :checkGETOPTSval
  if (%2)==() echo Missing argument for %1! & GOTO :usage
  GOTO :parseGETOPTSargs
  :checkGETOPTSval
    SET VAL=%2
    SET VAL=%VAL:~0,1%
    if %VAL% == - echo Missing argument for %1! & GOTO :usage
  :parseGETOPTSargs
  if /I %1 == -c SET CONTROLLER_ADDRESS=%~2& shift
  if /I %1 == -p SET CONTROLLER_PORT=%~2& shift
  if /I %1 == -u SET ACCOUNT_NAME=%~2& shift
  if /I %1 == -k SET ACCOUNT_ACCESS_KEY=%~2& shift
  if /I %1 == -s SET SSL=%~2& shift
  if /I %1 == -n SET NODE_PORT=%~2& shift
  if /I %1 == -a SET AXIS_PORT=%~2& shift
  if /I %1 == -m SET MYSQL_PORT=%~2& shift
:GETOPTS_END
  shift
if not (%1)==() GOTO :GETOPTS
CALL :startup
GOTO :Exit

:about
  %ucat% "%RUN_PATH%\about"
  echo.
  echo   ** About %REQUIRED_SPACE% kB of space is required in order to install the demo **
GOTO :EOF

:usage
  CALL :about
  %uprintf% "%%s" "usage: AppDemo.bat "
  %ucat% "%RUN_PATH%\usage"
  Exit /B 0
GOTO :EOF

:verifyUserAgreement
  if %NOPROMPT% == true Exit /B 0
  echo %1
  SET response=
  :verifyUserAgreementLoop
  set /p response=Please input "Y" to accept, or "n" to decline and quit:
  if %response% == n call :Exit
  if not %response% == Y GOTO :verifyUserAgreementLoop
GOTO :EOF

:removeEnvironment
  echo Removing Sample Application Environment...
  rmdir /S /Q "%RUN_PATH%"
  echo Done
  Exit /B 0
GOTO :EOF

:spaceCheck

GOTO :EOF

:startProcess

GOTO :EOF

:doNodeInstall
  if not exist "%NVM_DIR%\nvm.exe" (
    %uaria% https://github.com/coreybutler/nvm-windows/releases/download/1.0.6/nvm-noinstall.zip -d "%RUN_PATH%" -o nvm.zip
    %uunzip% "%RUN_PATH%\nvm.zip" -d "%NVM_DIR%"
    DEL "%RUN_PATH%\nvm.zip" 2>NUL
  )
  echo root: %NVM_HOME% > "%NVM_DIR%\settings.txt"
  echo path: %NVM_SYMLINK% >> "%NVM_DIR%\settings.txt"
  echo arch: %OS% >> "%NVM_DIR%\settings.txt"
  "%NVM_DIR%\nvm.exe" install %NODE_VERSION%
  "%NVM_DIR%\nvm.exe" use %NODE_VERSION%

  REM echo "Verifying/Installing AppDynamics NodeJS Agent..."
  REM %npm% install "appdynamics@4.0.1" -g
  echo "Verifying/Installing Node Express..."
  %npm% install express -g
  echo "Verifying/Installing Node Request..."
  %npm% install request -g
  echo "Verifying/Installing Node xml2js..."
  %npm% install xml2js -g
GOTO :EOF

:startNode
  mkdir "%RUN_PATH%\node" 2>NUL
  mkdir "%RUN_PATH%\node\public" 2>NUL
  if not exist "%RUN_PATH%\node\server.js" xcopy "%SCRIPT_PATH%\src\server.js" "%RUN_PATH%\node"
  if not exist "%RUN_PATH%\node\public\index.html" xcopy /s "%SCRIPT_PATH%\src\public" "%RUN_PATH%\node\public"
  %node% "%RUN_PATH%\node\server.js"
GOTO :EOF

:startup
  if %CONTROLLER_ADDRESS%==false echo No Controller Address Specified! & GOTO :usage
  if %CONTROLLER_PORT%==false echo No Controller Port Specified! & GOTO :usage
  CALL :about
  if not %PROMPT_EACH_REQUEST% == true (
    CALL :verifyUserAgreement "Do you agree to install all of the required dependencies if they do not exist and continue?"
  )
  REM CALL :doNodeInstall
  CALL :startNode
GOTO :EOF

:Exit
  if not exist "%temp%\ExitBatchYes.txt" call :buildYes
  echo Killing all processes and cleaning up...
  DEL "%RUN_PATH%\cookies" 2>NUL
  DEL "$RUN_PATH\%status" 2>NUL
  ENDLOCAL
  call :CtrlC <"%temp%\ExitBatchYes.txt" 1>nul 2>&1
GOTO :EOF

:CtrlC
  cmd /c exit -1073741510
GOTO :EOF

:buildYes
  pushd "%temp%"
  set "yes="
  copy nul ExitBatchYes.txt >nul
  for /f "delims=(/ tokens=2" %%Y in (
    '"copy /-y nul ExitBatchYes.txt <nul"'
  ) do if not defined yes set "yes=%%Y"
  echo %yes%>ExitBatchYes.txt
  popd
GOTO :EOF