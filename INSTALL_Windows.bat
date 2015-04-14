@echo OFF

TITLE AppDynamicsSampleApp

SETLOCAL enabledelayedexpansion

REM Configure these values on download.
SET ACCOUNT_NAME=config-account-name
SET ACCOUNT_ACCESS_KEY=config-account-access-key
SET CONTROLLER_ADDRESS=config-controller-host
SET CONTROLLER_PORT=config-controller-port
SET CONTROLLER_SSL=config-controller-ssl-enabled
SET DATABASE_AGENT_VERSION=config-database-agent-version
SET JAVA_AGENT_VERSION=config-java-agent-version
SET MACHINE_AGENT_VERSION=config-machine-agent-version
DOWNLOAD_HOSTNAME=config-download-hostname

SET APPLICATION_NAME=AppDynamics Sample App (Windows)
SET BACKEND_PORT=8887
SET HTTP_PORT=8888
SET MYSQL_PORT=3306
SET AXIS_VERSION=1.6.2
SET ANT_VERSION=1.9.4
SET NODE_VERSION=0.10.33
SET NOPROMPT=false
SET PROMPT_EACH_REQUEST=false
SET APP_STARTED=false

SET LOGGED_IN=false
SET SCRIPT_DIR=%~dp0
SET SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
SET RUN_PATH=C:\AppDynamicsSampleApp
SET NVM_DIR=%RUN_PATH%\.nvm
SET NVM_HOME=%NVM_DIR%
SET NVM_SYMLINK=C:\Program Files\nodejs
SET NODE_DIR=%NVM_HOME%\v%NODE_VERSION%
SET NODE_PATH=%NODE_DIR%\node_modules
SET AXIS_DIR=axis2-%AXIS_VERSION%
SET AXIS2_HOME=%RUN_PATH%\%AXIS_DIR%
SET ANT_DIR=apache-ant-%ANT_VERSION%
SET ANT_HOME=%RUN_PATH%/%ANT_DIR%

SET APPD_MYSQL_PORT_FILE=%RUN_PATH%\mysql.port
SET APPD_TOMCAT_FILE=%RUN_PATH%\tomcat

SET INSTALL_PATH=false

mkdir "%RUN_PATH%" 2>NUL

SET ucurl="%RUN_PATH%\utils\curl.exe"

SET node="%NODE_DIR%\node.exe"
SET npm=%node% "%NODE_PATH%\npm\bin\npm-cli.js"

net session >nul 2>&1
if not %errorLevel% == 0 echo Please re-run this script with administrative permissions! & GOTO :Exit

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
  if /I %1 == -s SET CONTROLLER_SSL=%~2& shift
  if /I %1 == -n SET HTTP_PORT=%~2& shift
  if /I %1 == -j SET BACKEND_PORT=%~2& shift
  if /I %1 == -m SET MYSQL_PORT=%~2& shift
:GETOPTS_END
  shift
if not (%1)==() GOTO :GETOPTS
CALL :startup
GOTO :Exit

:about
  type "%SCRIPT_DIR%\README"
  echo.
GOTO :EOF

:usage
  CALL :about
  echo usage: AppDemo.bat
  type "%SCRIPT_DIR%\usage"
  Exit /B 0
GOTO :EOF

:verifyUserAgreement
  if not [%2] == [true] (
    if %NOPROMPT% == true Exit /B 0
  )
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
  echo ^<?xml version="1.0" encoding="UTF-8"?^> > "%WRITE_FILE%"
  echo ^<controller-info^> >> "%WRITE_FILE%"
	echo ^<controller-host^>%CONTROLLER_ADDRESS%^</controller-host^> >> "%WRITE_FILE%"
	echo ^<controller-port^>%CONTROLLER_PORT%^</controller-port^>  >> "%WRITE_FILE%"
	echo ^<controller-ssl-enabled^>%CONTROLLER_SSL%^</controller-ssl-enabled^> >> "%WRITE_FILE%"
	echo ^<account-name^>%ACCOUNT_NAME%^</account-name^> >> "%WRITE_FILE%"
	echo ^<account-access-key^>%ACCOUNT_ACCESS_KEY%^</account-access-key^> >> "%WRITE_FILE%"
	echo ^<application-name^>%APPLICATION_NAME%^</application-name^> >> "%WRITE_FILE%"
	echo ^<tier-name^>%TIER_NAME%^</tier-name^> >> "%WRITE_FILE%"
	echo ^<node-name^>%NODE_NAME%^</node-name^> >> "%WRITE_FILE%"
	echo ^</controller-info^> >> "%WRITE_FILE%"
GOTO :EOF

:removeEnvironment
  echo Removing Sample Application Environment...
  rmdir /S /Q "%RUN_PATH%"
  echo Done
  Exit /B 0
GOTO :EOF

:performUnzip
  SET VB_ZIP_LOCATION=%~1
  SET VB_EXTRACT_LOCATION=%~2
  mkdir "%VB_EXTRACT_LOCATION%" 2>NUL
  CALL cscript.exe "%SCRIPT_DIR%\vbs\unzip.vbs" >NUL
GOTO :EOF

:downloadCurl
  echo Verifying/Installing curl...
  if exist "%RUN_PATH%\utils\curl.exe" GOTO :EOF
  CALL :verifyUserAgreement "curl needs to be downloaded, do you wish to continue?"
  SET VB_DOWNLOAD_URL="http://www.paehl.com/open_source/?download=curl_741_0_ssl.zip"
  SET VB_ZIP_LOCATION=%RUN_PATH%\curl.zip
  CALL cscript.exe "%SCRIPT_DIR%\vbs\download.vbs" >NUL
  CALL :performUnzip "%RUN_PATH%\curl.zip" "%RUN_PATH%\utils"
  DEL "%RUN_PATH%\curl.zip" >NUL
GOTO :EOF

:verifyJava
  if not exist "%JAVA_HOME%\bin\java.exe" echo Please make sure your JAVA_HOME environment variable is defined correctly, exiting. & CALL :Exit
GOTO :EOF

:verifyMySQL
  for %%X in (mysql.exe) do (SET APPD_MYSQL_EXEC=%%~$PATH:X)
  if not defined APPD_MYSQL_EXEC echo MySQL is needed to continue.  Please ensure your PATH environment variable is properly configured to include where the mysql executable is located, exiting. & CALL :Exit
  echo %MYSQL_PORT% > "%APPD_MYSQL_PORT_FILE%"
GOTO :EOF

:createMySQLDatabase
  echo Please login to mysql with root to setup the database for the demo application...
  %APPD_MYSQL_EXEC% -u root -p < "%SCRIPT_DIR%\src\mysql.sql"
  if not %errorlevel% == 0 (
    CALL :verifyUserAgreement "The mysql script install/check failed, do you wish to try again?" true
    CALL :createMySQLDatabase
  )
GOTO :EOF

:performTomcatDependencyDownload
  SET TOMCAT_DEPENDENCY_FOLDER=%1
  SET "TOMCAT_DEPENDENCY_FOLDER=!TOMCAT_DEPENDENCY_FOLDER:/=\!"
  if exist "%RUN_PATH%\tomcatrest\repo\%TOMCAT_DEPENDENCY_FOLDER%" GOTO :EOF
  echo Downloading http://repo.maven.apache.org/maven2/%1
  %ucurl% -q --create-dirs -L -o "%RUN_PATH%\tomcatrest\repo\%TOMCAT_DEPENDENCY_FOLDER%" http://repo.maven.apache.org/maven2/%1
GOTO :EOF

:installTomcat
  echo Setting up Tomcat...
  echo %BACKEND_PORT% > "%APPD_TOMCAT_FILE%"
  mkdir %RUN_PATH%\tomcatrest\repo 2>NUL
  mkdir %RUN_PATH%\tomcatrest\bin 2>NUL
  xcopy /e /y "%SCRIPT_DIR%\sampleapp" "%RUN_PATH%\tomcatrest" >NUL
  CALL :performTomcatDependencyDownload org/glassfish/jersey/containers/jersey-container-servlet/2.10.1/jersey-container-servlet-2.10.1.jar
  CALL :performTomcatDependencyDownload org/glassfish/jersey/containers/jersey-container-servlet-core/2.10.1/jersey-container-servlet-core-2.10.1.jar
  CALL :performTomcatDependencyDownload org/glassfish/hk2/external/javax.inject/2.3.0-b05/javax.inject-2.3.0-b05.jar
  CALL :performTomcatDependencyDownload org/glassfish/jersey/core/jersey-common/2.10.1/jersey-common-2.10.1.jar
  CALL :performTomcatDependencyDownload javax/annotation/javax.annotation-api/1.2/javax.annotation-api-1.2.jar
  CALL :performTomcatDependencyDownload org/glassfish/jersey/bundles/repackaged/jersey-guava/2.10.1/jersey-guava-2.10.1.jar
  CALL :performTomcatDependencyDownload org/glassfish/hk2/hk2-api/2.3.0-b05/hk2-api-2.3.0-b05.jar
  CALL :performTomcatDependencyDownload org/glassfish/hk2/hk2-utils/2.3.0-b05/hk2-utils-2.3.0-b05.jar
  CALL :performTomcatDependencyDownload org/glassfish/hk2/external/aopalliance-repackaged/2.3.0-b05/aopalliance-repackaged-2.3.0-b05.jar
  CALL :performTomcatDependencyDownload org/glassfish/hk2/hk2-locator/2.3.0-b05/hk2-locator-2.3.0-b05.jar
  CALL :performTomcatDependencyDownload org/javassist/javassist/3.18.1-GA/javassist-3.18.1-GA.jar
  CALL :performTomcatDependencyDownload org/glassfish/hk2/osgi-resource-locator/1.0.1/osgi-resource-locator-1.0.1.jar
  CALL :performTomcatDependencyDownload org/glassfish/jersey/core/jersey-server/2.10.1/jersey-server-2.10.1.jar
  CALL :performTomcatDependencyDownload org/glassfish/jersey/core/jersey-client/2.10.1/jersey-client-2.10.1.jar
  CALL :performTomcatDependencyDownload javax/validation/validation-api/1.1.0.Final/validation-api-1.1.0.Final.jar
  CALL :performTomcatDependencyDownload javax/ws/rs/javax.ws.rs-api/2.0/javax.ws.rs-api-2.0.jar
  CALL :performTomcatDependencyDownload mysql/mysql-connector-java/5.1.6/mysql-connector-java-5.1.6.jar
  CALL :performTomcatDependencyDownload org/apache/tomcat/embed/tomcat-embed-logging-juli/7.0.57/tomcat-embed-logging-juli-7.0.57.jar
  CALL :performTomcatDependencyDownload org/apache/tomcat/embed/tomcat-embed-jasper/7.0.57/tomcat-embed-jasper-7.0.57.jar
  CALL :performTomcatDependencyDownload org/apache/tomcat/embed/tomcat-embed-el/7.0.57/tomcat-embed-el-7.0.57.jar
  CALL :performTomcatDependencyDownload org/eclipse/jdt/core/compiler/ecj/4.4/ecj-4.4.jar
  CALL :performTomcatDependencyDownload org/apache/tomcat/embed/tomcat-embed-core/7.0.57/tomcat-embed-core-7.0.57.jar
GOTO :EOF

:doNodeDependencyInstall
  echo Verifiying/Installing %1
  %npm% install %1 -g
GOTO :EOF

:installNode
  if not exist "%NVM_DIR%\nvm.exe" (
    echo Downloading NVM...
    %ucurl% -q -o "%RUN_PATH%\nvm.zip" -L --insecure "https://github.com/coreybutler/nvm-windows/releases/download/1.0.6/nvm-noinstall.zip"
    CALL :performUnzip "%RUN_PATH%\nvm.zip" "%NVM_DIR%"
    DEL "%RUN_PATH%\nvm.zip" 2>NUL
  )
  echo root: %NVM_HOME% > "%NVM_DIR%\settings.txt"
  echo path: %NVM_SYMLINK% >> "%NVM_DIR%\settings.txt"
  %NVM_DIR%\nvm.exe install %NODE_VERSION%
  %NVM_DIR%\nvm.exe use %NODE_VERSION%

  echo Verifying/Installing Node Express...
  CALL :doNodeDependencyInstall express@4.12.3
  CALL :doNodeDependencyInstall request@2.55.0
  CALL :doNodeDependencyInstall jquery@2.1.3
  CALL :doNodeDependencyInstall bootstrap@3.3.4
  CALL :doNodeDependencyInstall angular@1.3.14
GOTO :EOF

:resetAgentUP
  SET __APPD_USERNAME=
  SET __APPD_PASSWORD=
GOTO :EOF

:agentInstall
  SET AGENT_DIR=%~1
  SET AGENT_CHECK_FILE=%~2
  SET AGENT_URL=%~3
  echo Verifying/Installing AppDynamics %AGENT_DIR%...
  if exist "%RUN_PATH%\%AGENT_DIR%\%AGENT_CHECK_FILE%" echo INSTALLED & GOTO :EOF
  mkdir %RUN_PATH%\%AGENT_DIR% 2>NUL
  if not %LOGGED_IN% == true (
    :agentInstallLoop
    if exist "%RUN_PATH\cookies" ( echo Invalid Username/Password
    ) else ( echo Please Sign in, in order to download AppDynamics Agents
    )
    SET /p __APPD_USERNAME=Username:
    SET /p __APPD_PASSWORD=Password:
    %ucurl% -q -o NUL --cookie-jar "%RUN_PATH%\cookies" --data "username=%__APPD_USERNAME%&password=%__APPD_PASSWORD%" --insecure "https://login.appdynamics.com/sso/login/" 1>NUL 2>&1
    CALL :resetAgentUP
    if not exist "%RUN_PATH%\cookies" GOTO :agentInstallLoop
    findstr /m "login.appdynamics.com" "%RUN_PATH%\cookies" 1>NUL 2>&1
    if %ERRORLEVEL% == 1 GOTO :agentInstallLoop
    SET LOGGED_IN=true
  )
  %ucurl% -q -L -o "%RUN_PATH%\%AGENT_DIR%.zip" --cookie "%RUN_PATH%\cookies" --insecure "%AGENT_URL%"
  echo Unpacking %AGENT_DIR% (this may take a few minutes)...
  CALL :performUnzip "%RUN_PATH%\%AGENT_DIR%.zip" "%RUN_PATH%\%AGENT_DIR%"
  DEL "%RUN_PATH%\%AGENT_DIR%.zip"
GOTO :EOF

:installAgents
  CALL :agentInstall "MachineAgent" "machineagent.jar" "https://%DOWNLOAD_HOSTNAME%/saas/public/archives/%MACHINE_AGENT_VERSION%/MachineAgent-%MACHINE_AGENT_VERSION%.zip"
  CALL :agentInstall "DatabaseAgent" "db-agent.jar" "https://%DOWNLOAD_HOSTNAME%/saas/public/archives/%DATABASE_AGENT_VERSION%/dbagent-%DATABASE_AGENT_VERSION%.zip"
  CALL :agentInstall "AppServerAgent" "javaagent.jar" "https://%DOWNLOAD_HOSTNAME%/saas/public/archives/%JAVA_AGENT_VERSION%/AppServerAgent-%JAVA_AGENT_VERSION%.zip"
GOTO :EOF

:startMachineAgent
  echo Starting Machine Agent...
  CALL :writeControllerInfo "%RUN_PATH%\MachineAgent\conf\controller-info.xml"
  start "_AppDynamicsSampleApp_ Machine Agent" /MIN "%JAVA_HOME%\bin\java.exe" -jar %RUN_PATH%\MachineAgent\machineagent.jar
GOTO :EOF

:startDatabaseAgent
  echo Starting Database Agent...
  CALL :writeControllerInfo "%RUN_PATH%\DatabaseAgent\conf\controller-info.xml"
  start "_AppDynamicsSampleApp_ Database Agent" /MIN "%JAVA_HOME%\bin\java.exe" -Dappdynamics.controller.hostName=%CONTROLLER_ADDRESS% -Dappdynamics.controller.port=%CONTROLLER_PORT% -Dappdynamics.controller.ssl.enabled=%CONTROLLER_SSL% -Dappdynamics.agent.accountName=%ACCOUNT_NAME% -Dappdynamics.agent.accountAccessKey=%ACCOUNT_ACCESS_KEY% -jar %RUN_PATH%\DatabaseAgent\db-agent.jar
GOTO :EOF

:startTomcat
  CALL :writeControllerInfo "%RUN_PATH%\AppServerAgent\conf\controller-info.xml" "JavaServer" "JavaServer01"
  CALL :writeControllerInfo "%RUN_PATH%\AppServerAgent\ver%JAVA_AGENT_VERSION%\conf\controller-info.xml" "JavaServer" "JavaServer01"
  SET JAVA_OPTS=-javaagent:%RUN_PATH%\AppServerAgent\javaagent.jar
  echo Starting Tomcat...
  start "_AppDynamicsSampleApp_ Tomcat" /MIN "%RUN_PATH%\tomcatrest\bin\SampleAppServer.bat"
GOTO :EOF

:startNode
  mkdir "%RUN_PATH%\node" 2>NUL
  if not exist "%RUN_PATH%\node\server.js" mklink "%RUN_PATH%\node\server.js" "%SCRIPT_DIR%\src\server.js" >NUL
  if not exist "%RUN_PATH%\node\public\angular" mklink /D "%SCRIPT_DIR%\src\public\angular" "%NODE_PATH%\angular" >NUL
  if not exist "%RUN_PATH%\node\public\angular-route" mklink /D "%SCRIPT_DIR%\src\public\angular-route" "%NODE_PATH%\angular-route" >NUL
  if not exist "%RUN_PATH%\node\public\bootstrap" mklink /D "%SCRIPT_DIR%\src\public\bootstrap" "%NODE_PATH%\bootstrap\dist" >NUL
  if not exist "%RUN_PATH%\node\public\jquery" mklink /D "%SCRIPT_DIR%\src\public\jquery" "%NODE_PATH%\jquery\dist" >NUL
  if not exist "%RUN_PATH%\node\public" mklink /D "%RUN_PATH%\node\public" "%SCRIPT_DIR%\src\public" >NUL
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
  CALL :downloadCurl
  CALL :verifyJava
  CALL :verifyMySQL
  CALL :createMySQLDatabase
  CALL :installTomcat
  CALL :installNode
  CALL :installAgents
  CALL :startMachineAgent
  CALL :startDatabaseAgent
  CALL :startTomcat
  CALL :startNode

  echo The AppDynamics Sample App Environment has been started.
  echo Please wait a few moments for the environment to initialize then:
  echo Visit http://localhost:%HTTP_PORT%
  echo Press any key to quit...
  Pause >NUL
  CALL :Exit
GOTO :EOF

:Exit
  if not exist "%temp%\ExitBatchYes.txt" call :buildYes
  echo Killing all processes and cleaning up...
  DEL "%RUN_PATH%\cookies" 2>NUL
  DEL "%RUN_PATH%\status" 2>NUL
  DEL "%RUN_PATH%\varout" 2>NUL
  DEL "%APPD_TOMCAT_FILE%" 2>NUL
  taskkill /FI "WINDOWTITLE eq _AppDynamicsSampleApp_*" 1>NUL 2>&1
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
  for /f "delims=(/ tokens=2" %%Y in ('"copy /-y nul ExitBatchYes.txt <nul"') do if not defined yes set "yes=%%Y"
  echo %yes%>ExitBatchYes.txt
  popd
GOTO :EOF