@echo OFF

TITLE AppDynamicsSampleApp

SETLOCAL
SET APPLICATION_NAME=TestApplication
SET JAVA_PORT=8887
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
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=32 || set OS=64

SET LOGGED_IN=false
SET SCRIPT_PATH=%~dp0
SET SCRIPT_PATH=%SCRIPT_PATH:~0,-1%
SET RUN_PATH=C:\AppDynamics
SET NVM_DIR=%RUN_PATH%\.nvm
SET NVM_HOME=%NVM_DIR%
SET NVM_SYMLINK=C:\Program Files\nodejs
SET NODE_DIR=%NVM_HOME%\v%NODE_VERSION%
SET NODE_PATH=%NODE_DIR%\node_modules
SET AXIS_DIR=axis2-%AXIS_VERSION%
SET AXIS2_HOME=%RUN_PATH%\%AXIS_DIR%
SET ANT_DIR=apache-ant-%ANT_VERSION%
SET ANT_HOME=%RUN_PATH%/%ANT_DIR%

SET APPD_MYSQL_PORT_FILE=%RUN_PATH%\mysql\mysql.port
SET APPD_TOMCAT_FILE=%RUN_PATH%\tomcat

mkdir "%RUN_PATH%" 2>NUL

SET ucat="%SCRIPT_PATH%\utils\unixutils\cat.exe"
SET uprintf="%SCRIPT_PATH%\utils\unixutils\printf.exe"
SET uaria="%SCRIPT_PATH%\utils\aria2\aria2c.exe"
SET uunzip="%SCRIPT_PATH%\utils\unixutils\unzip.exe"
SET used="%SCRIPT_PATH%\utils\unixutils\sed.exe"
SET ugrep="%SCRIPT_PATH%\utils\unixutils\grep.exe"
SET uwget="%SCRIPT_PATH%\utils\gnu\wget.exe"

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
  if /I %1 == -j GOTO :verifyVal
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
  if /I %1 == -j SET JAVA_PORT=%~2& shift
  if /I %1 == -m SET MYSQL_PORT=%~2& shift
:GETOPTS_END
  shift
if not (%1)==() GOTO :GETOPTS
CALL :startup
GOTO :Exit

:about
  %ucat% "%SCRIPT_PATH%\about"
  echo.
GOTO :EOF

:usage
  CALL :about
  %uprintf% "%%s" "usage: AppDemo.bat "
  %ucat% "%SCRIPT_PATH%\usage"
  Exit /B 0
GOTO :EOF

:verifyUserAgreement
  if %NOPROMPT% == true Exit /B 0
  echo %~1
  SET response=
  :verifyUserAgreementLoop
  set /p response=Please input "Y" to accept, or "n" to decline and quit:
  if %response% == n CALL :Exit
  if not %response% == Y GOTO :verifyUserAgreementLoop
GOTO :EOF

:writeControllerInfo
  SET WRITE_FILE=%~1
  SET TIER_NAME=%~2
  SET NODE_NAME=%~3
  %uprintf% "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "%WRITE_FILE%"
  %uprintf% "<controller-info>" >> "%WRITE_FILE%"
	%uprintf% "<controller-host>%%s</controller-host>" %CONTROLLER_ADDRESS% >> "%WRITE_FILE%"
	%uprintf% "<controller-port>%%s</controller-port>" %CONTROLLER_PORT% >> "%WRITE_FILE%"
	%uprintf% "<controller-ssl-enabled>%%s</controller-ssl-enabled>" %SSL% >> "%WRITE_FILE%"
	%uprintf% "<account-name>%%s</account-name>" %ACCOUNT_NAME% >> "%WRITE_FILE%"
	%uprintf% "<account-access-key>%%s</account-access-key>" %ACCOUNT_ACCESS_KEY% >> "%WRITE_FILE%"
	%uprintf% "<application-name>%%s</application-name>" %APPLICATION_NAME% >> "%WRITE_FILE%"
	%uprintf% "<tier-name>%%s</tier-name>" %TIER_NAME% >> "%WRITE_FILE%"
	%uprintf% "<node-name>%%s</node-name>" %NODE_NAME% >> "%WRITE_FILE%"
	%uprintf% "</controller-info>" >> "%WRITE_FILE%"
GOTO :EOF

:removeEnvironment
  echo Removing Sample Application Environment...
  rmdir /S /Q "%RUN_PATH%"
  echo Done
  Exit /B 0
GOTO :EOF

:verifyJava
  if not exist "%JAVA_HOME%\bin\java.exe" echo Please make sure your JAVA_HOME environment variable is defined correctly & CALL :Exit
GOTO :EOF

:doMySqlInstall
  echo Verifying/Installing MySql...
  if exist "%RUN_PATH%\mysql\bin\mysqld.exe" echo Installed & GOTO :EOF
  CALL :verifyUserAgreement "An instance of MySql needs to be downloaded, do you wish to continue?"
  SET MS_DLOAD_FILE=mysql-5.6.23-win32.zip
  if %OS% == 64 SET MS_DLOAD_FILE=mysql-5.6.23-winx64.zip
  %uaria% "http://dev.mysql.com/get/Downloads/MySQL-5.6/%MS_DLOAD_FILE%" -d "%RUN_PATH%" -o "mysql.zip"
  echo Unpacking MySql (this process may take a few minutes)...
  %uunzip% "%RUN_PATH%\mysql.zip" -d "%RUN_PATH%" >NUL
  DEL "%RUN_PATH%\mysql.zip">NUL
  for /D %%i in (%RUN_PATH%\mysql-*) do move %%i "%RUN_PATH%\mysql" >NUL
GOTO :EOF

:doTomcatInstall
  echo Setting up Tomcat...
  echo %JAVA_PORT% > "%APPD_TOMCAT_FILE%"
  if not exist "%RUN_PATH%\tomcatrest\storefront.jar" mklink /D "%RUN_PATH%\tomcatrest" "%SCRIPT_PATH%\src\tomcat" >NUL
GOTO :EOF

:startTomcat
  CALL :writeControllerInfo "%RUN_PATH%\AppServerAgent\conf\controller-info.xml" "JavaServer" "JavaServer01"
  CALL :writeControllerInfo "%RUN_PATH%\AppServerAgent\ver%APPSERVER_AGENT_VERSION%\conf\controller-info.xml" "JavaServer" "JavaServer01"
  SET JAVA_OPTS=-javaagent:%RUN_PATH%\AppServerAgent\javaagent.jar
  echo Starting Tomcat...
  start "_AppDynamicsSampleApp_ Tomcat" /MIN "%RUN_PATH%\tomcatrest\bin\webapp.bat"
GOTO :EOF

:startMySql
  echo Starting MySql...
  start "_AppDynamicsSampleApp_ MySql" /MIN "%RUN_PATH%\mysql\bin\mysqld.exe" --no-defaults --basedir=%RUN_PATH%\mysql --datadir=%RUN_PATH%\mysql\data --pid-file=%RUN_PATH%\mysql\data\mysql.pid --port=%MYSQL_PORT% --log-error=%RUN_PATH%\mysql\mysql.err --init-file="%SCRIPT_PATH%\src\mysql.sql"
  echo %MYSQL_PORT% > "%APPD_MYSQL_PORT_FILE%"
GOTO :EOF

:resetAgentUP
  SET __APPD_USERNAME=
  SET __APPD_PASSWORD=
GOTO :EOF

:agentInstall
  SET AGENT_DIR=%~1
  SET AGENT_CHECK_FILE=%~2
  SET AGENT_URL=%~3
  echo Verifying/Install AppDynamics %AGENT_DIR%...
  if exist "%RUN_PATH%\%AGENT_DIR%\%AGENT_CHECK_FILE%" echo INSTALLED & GOTO :EOF
  mkdir /S /Q %RUN_PATH%\%AGENT_DIR%
  if not %LOGGED_IN% == true (
    GOTO :agentInstallLoopCheck
    :agentInstallLoop
    if exist "%RUN_PATH\cookies" ( echo Invalid Username/Password
    ) else ( echo Please Sign in, in order to download AppDynamics Agents
    )
    SET /p __APPD_USERNAME=Username:
    SET /p __APPD_PASSWORD=Password:
    %uwget% -q -O NUL --save-cookies "%RUN_PATH%\cookies" --post-data "username=%__APPD_USERNAME%&password=%__APPD_PASSWORD%" --no-check-certificate "https://login.appdynamics.com/sso/login/" >NUL
    :agentInstallLoopCheck
    CALL :resetAgentUP
    %ugrep% -s -q login.appdynamics.com "%RUN_PATH%\cookies"
    if %ERRORLEVEL% == 1 GOTO :agentInstallLoop
    SET LOGGED_IN=true
  )
  %uaria% --load-cookies "%RUN_PATH%\cookies" "%AGENT_URL%" -d "%RUN_PATH%\%AGENT_DIR%" -o "%AGENT_DIR%.zip"
  echo Unpacking %AGENT_DIR% (this may take a few minutes)...
  %uunzip% "%RUN_PATH%\%AGENT_DIR%\%AGENT_DIR%.zip" -d "%RUN_PATH%\%AGENT_DIR%" >NUL
  DEL "%RUN_PATH%\%AGENT_DIR%\%AGENT_DIR%.zip"
GOTO :EOF

:doAgentInstalls
  CALL :agentInstall "AppServerAgent" "javaagent.jar" "https://download.appdynamics.com/saas/public/archives/%APPSERVER_AGENT_VERSION%/AppServerAgent-%APPSERVER_AGENT_VERSION%.zip"
GOTO :EOF

:doNodeDependencyInstall
  echo Verifiying/Installing %1
  %npm% install %1 -g
GOTO :EOF

:doNodeInstall
  if not exist "%NVM_DIR%\nvm.exe" (
    echo Downloading NVM...
    %uaria% https://github.com/coreybutler/nvm-windows/releases/download/1.0.6/nvm-noinstall.zip -d "%RUN_PATH%" -o nvm.zip
    %uunzip% "%RUN_PATH%\nvm.zip" -d "%NVM_DIR%" >NUL
    DEL "%RUN_PATH%\nvm.zip" 2>NUL
  )
  echo root: %NVM_HOME% > "%NVM_DIR%\settings.txt"
  echo path: %NVM_SYMLINK% >> "%NVM_DIR%\settings.txt"
  echo arch: %OS% >> "%NVM_DIR%\settings.txt"
  %NVM_DIR%\nvm.exe install %NODE_VERSION%
  %NVM_DIR%\nvm.exe use %NODE_VERSION%

  echo Verifying/Installing Node Express...
  CALL :doNodeDependencyInstall express
  CALL :doNodeDependencyInstall request
  CALL :doNodeDependencyInstall jquery@2.1.3
  CALL :doNodeDependencyInstall bootstrap@3.3.4
  CALL :doNodeDependencyInstall angular@1.3.14
  CALL :doNodeDependencyInstall angular-route@1.3.14
GOTO :EOF

:startNode
  mkdir "%RUN_PATH%\node" 2>NUL
  if not exist "%RUN_PATH%\node\server.js" mklink "%RUN_PATH%\node\server.js" "%SCRIPT_PATH%\src\server.js" >NUL
  if not exist "%RUN_PATH%\node\public\angular" mklink /D "%SCRIPT_PATH%\src\public\angular" "%NODE_PATH%\angular" >NUL
  if not exist "%RUN_PATH%\node\public\angular-route" mklink /D "%SCRIPT_PATH%\src\public\angular-route" "%NODE_PATH%\angular-route" >NUL
  if not exist "%RUN_PATH%\node\public\bootstrap" mklink /D "%SCRIPT_PATH%\src\public\bootstrap" "%NODE_PATH%\bootstrap\dist" >NUL
  if not exist "%RUN_PATH%\node\public\jquery" mklink /D "%SCRIPT_PATH%\src\public\jquery" "%NODE_PATH%\jquery\dist" >NUL
  if not exist "%RUN_PATH%\node\public" mklink /D "%RUN_PATH%\node\public" "%SCRIPT_PATH%\src\public" >NUL
  echo Starting Node...
  start "_AppDynamicsSampleApp_ Node" /MIN "%node%" "%RUN_PATH%\node\server.js"
GOTO :EOF

:startup
  if %CONTROLLER_ADDRESS%==false echo No Controller Address Specified! & GOTO :usage
  if %CONTROLLER_PORT%==false echo No Controller Port Specified! & GOTO :usage
  CALL :about
  if not %PROMPT_EACH_REQUEST% == true (
    CALL :verifyUserAgreement "Do you agree to install all of the required dependencies if they do not exist and continue?"
    SET NOPROMPT=true
  )
  CALL :verifyJava
  CALL :doTomcatInstall
  CALL :doMySqlInstall
  CALL :doAgentInstalls
  CALL :startMySql
  CALL :doNodeInstall
  CALL :startTomcat
  CALL :startNode

  echo The AppDynamics Sample App Environment has been started.
  echo Please wait a few moments for the environment to initialize then:
  echo Visit http://localhost:%NODE_PORT%
  echo Press any key to quit...
  Pause >NUL
GOTO :EOF

:Exit
  if not exist "%temp%\ExitBatchYes.txt" call :buildYes
  echo Killing all processes and cleaning up...
  DEL "%RUN_PATH%\cookies" 2>NUL
  DEL "%RUN_PATH%\status" 2>NUL
  DEL "%RUN_PATH%\varout" 2>NUL
  DEL "%APPD_TOMCAT_FILE%" 2>NUL
  taskkill /FI "WINDOWTITLE eq _AppDynamicsSampleApp_*" 1>NUL 2>&1
  taskkill /F /IM mysqld.exe 1>NUL 2>&1
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