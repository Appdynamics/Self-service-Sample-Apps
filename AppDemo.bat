@echo OFF

TITLE AppDynamicsSampleApp

SETLOCAL
SET APPLICATION_NAME=TestApplication
SET BACKEND_PORT=8887
SET HTTP_PORT=8888
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
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OSBIT=32 || set OSBIT=64

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

SET INSTALL_PATH=false

mkdir "%RUN_PATH%" 2>NUL

SET ucat="%RUN_PATH%\utils\unixutils\usr\local\wbin\cat.exe"
SET uprintf="%RUN_PATH%\utils\unixutils\usr\local\wbin\printf.exe"
SET uunzip="%RUN_PATH%\utils\unixutils\usr\local\wbin\unzip.exe"
SET used="%RUN_PATH%\utils\unixutils\usr\local\wbin\sed.exe"
SET ugrep="%RUN_PATH%\utils\unixutils\usr\local\wbin\grep.exe"
SET uwget="%RUN_PATH%\utils\wget.exe"

SET node="%NODE_DIR%\node.exe"
SET npm=%node% "%NODE_PATH%\npm\bin\npm-cli.js"

SET iis="%windir%\system32\inetsrv\AppCmd.exe"

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
  if /I %1 == -s SET SSL=%~2& shift
  if /I %1 == -n SET HTTP_PORT=%~2& shift
  if /I %1 == -j SET BACKEND_PORT=%~2& shift
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
  if exists "%iis%" %iis% delete site "AppDemo .NET REST Server"
  echo Done
  Exit /B 0
GOTO :EOF

:downloadWget
  echo Verifying/Installing wget...
  if exist "%RUN_PATH%\utils\wget.exe" GOTO :EOF
  CALL :verifyUserAgreement "wget needs to be downloaded, do you wish to continue?"
  mkdir "%RUN_PATH%\utils" 2>NUL
  SET VB_DOWNLOAD_URL="https://eternallybored.org/misc/wget/wget-1.16.3-win32.zip"
  SET VB_ZIP_LOCATION=%RUN_PATH%\wget.zip
  SET VB_EXTRACT_LOCATION=%RUN_PATH%\utils
  CALL cscript.exe "%SCRIPT_PATH%\downloadWget.vbs" >NUL
  CALL cscript.exe "%SCRIPT_PATH%\unzip.vbs" >NUL
  DEL "%RUN_PATH%\wget.zip" >NUL
GOTO :EOF

:downloadDependencies
  echo Verifying/Installing unixutils...
  if exist "%uunzip%" GOTO :EOF
  mkdir "%RUN_PATH%\utils\unixutils" 2>NUL
  %uwget% http://sourceforge.net/projects/unxutils/files/latest/download -O "%RUN_PATH%\unixutils.zip"
  SET VB_ZIP_LOCATION=%RUN_PATH%\unixutils.zip
  SET VB_EXTRACT_LOCATION=%RUN_PATH%\utils\unixutils
  CALL cscript.exe "%SCRIPT_PATH%\unzip.vbs" >NUL
  DEL "%RUN_PATH%\unixutils.zip">NUL
GOTO :EOF

:determineInstallPath
  echo Do you wish to run a Java demo (Java (Tomcat) REST Server with All Agents), or .NET demo (with only the .NET agent)?
  SET response=
  SET INSTALL_PATH=false
  :verifyInstallPathLoop
  set /p response=Please input "J" for Java, or "N" for .NET:
  if %response% == J SET INSTALL_PATH=Java
  if %response% == N SET INSTALL_PATH=NET
  if %INSTALL_PATH% == false GOTO :verifyInstallPathLoop
GOTO :EOF

:verifyJava
  if not exist "%JAVA_HOME%\bin\java.exe" echo Please make sure your JAVA_HOME environment variable is defined correctly & CALL :Exit
GOTO :EOF

:verifyNET
  if not exist "%iis%" echo Please make sure you have IIS 7.0+ installed to continue & CALL :Exit
GOTO :EOF

:setupNET
  mkdir "%RUN_PATH%\net" 2>NUL
  if not exist "%RUN_PATH%\net\server.asp" mklink "%RUN_PATH%\net\server.asp" "%SCRIPT_PATH%\src\net\server.asp" >NUL
  %iis% list sites /name:"AppDemo .NET REST Server" >NUL
  if %ERRORLEVEL% == 1 (
    echo Creating AppDemo .NET REST Instance...
    %iis% add sites /name:"AppDemo .NET REST Server" /bindings:http/*:%BACKEND_PORT%: /physicalPath:%RUN_PATH%\net
  )
GOTO :EOF

:doMySqlInstall
  echo Verifying/Installing MySql...
  if exist "%RUN_PATH%\mysql\bin\mysqld.exe" echo Installed & GOTO :EOF
  CALL :verifyUserAgreement "An instance of MySql needs to be downloaded, do you wish to continue?"
  SET MS_DLOAD_FILE=mysql-5.6.23-win32.zip
  if %OSBIT% == 64 SET MS_DLOAD_FILE=mysql-5.6.23-winx64.zip
  %uwget% "http://dev.mysql.com/get/Downloads/MySQL-5.6/%MS_DLOAD_FILE%" -O "%RUN_PATH%\mysql.zip"
  echo Unpacking MySql (this process may take a few minutes)...
  %uunzip% "%RUN_PATH%\mysql.zip" -d "%RUN_PATH%" >NUL
  DEL "%RUN_PATH%\mysql.zip">NUL
  for /D %%i in (%RUN_PATH%\mysql-*) do move %%i "%RUN_PATH%\mysql" >NUL
GOTO :EOF

:performTomcatDependencyDownload
  %uwget% http://repo.maven.apache.org/maven2/%1 -x --cut-dirs=1 -nH -P "%RUN_PATH%\tomcatrest\repo"
GOTO :EOF

:doTomcatInstall
  echo Setting up Tomcat...
  echo %BACKEND_PORT% > "%APPD_TOMCAT_FILE%"
  mkdir %RUN_PATH%\tomcatrest\repo 2>NUL
  mkdir %RUN_PATH%\tomcatrest\bin 2>NUL
  if not exist "%RUN_PATH%\tomcatrest\repo\appdrestserver.jar" copy "%SCRIPT_PATH%\repo\appdrestserver.jar" "%RUN_PATH%\tomcatrest\repo\appdrestserver.jar" >NUL
  if not exist "%RUN_PATH%\tomcatrest\bin\AppDemoRESTServer.bat" copy "%SCRIPT_PATH%\AppDemoRESTServer.bat" "%RUN_PATH%\tomcatrest\bin\AppDemoRESTServer.bat" >NUL
  if exist "%RUN_PATH%\tomcatrest\repo\org\apache\tomcat\embed\tomcat-embed-core\7.0.57\tomcat-embed-core-7.0.57.jar" GOTO :EOF
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

:startTomcat
  CALL :writeControllerInfo "%RUN_PATH%\AppServerAgent\conf\controller-info.xml" "JavaServer" "JavaServer01"
  CALL :writeControllerInfo "%RUN_PATH%\AppServerAgent\ver%APPSERVER_AGENT_VERSION%\conf\controller-info.xml" "JavaServer" "JavaServer01"
  SET JAVA_OPTS=-javaagent:%RUN_PATH%\AppServerAgent\javaagent.jar
  echo Starting Tomcat...
  start "_AppDynamicsSampleApp_ Tomcat" /MIN "%RUN_PATH%\tomcatrest\bin\AppDemoRESTServer.bat"
GOTO :EOF

:startNET
  echo Starting IIS Instance
  %iis% start site "AppDemo .NET REST Server"
  if not %ERRORLEVEL% == 0 echo Unable to start IIS Instance, exiting. & CALL :Exit
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
  mkdir %RUN_PATH%\%AGENT_DIR% 2>NUL
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
  %uwget% --load-cookies "%RUN_PATH%\cookies" "%AGENT_URL%" --no-check-certificate -O "%RUN_PATH%\%AGENT_DIR%.zip"
  echo Unpacking %AGENT_DIR% (this may take a few minutes)...
  %uunzip% "%RUN_PATH%\%AGENT_DIR%.zip" -d "%RUN_PATH%\%AGENT_DIR%" >NUL
  DEL "%RUN_PATH%\%AGENT_DIR%.zip"
GOTO :EOF

:doJavaAgentInstalls
  CALL :agentInstall "MachineAgent" "machineagent.jar" "https://download.appdynamics.com/saas/public/archives/%MACHINE_AGENT_VERSION%/MachineAgent-%MACHINE_AGENT_VERSION%.zip"
  CALL :agentInstall "DatabaseAgent" "db-agent.jar" "https://download.appdynamics.com/saas/public/archives/%DATABASE_AGENT_VERSION%/dbagent-%DATABASE_AGENT_VERSION%.zip"
  CALL :agentInstall "AppServerAgent" "javaagent.jar" "https://download.appdynamics.com/saas/public/archives/%APPSERVER_AGENT_VERSION%/AppServerAgent-%APPSERVER_AGENT_VERSION%.zip"
GOTO :EOF

:doNodeDependencyInstall
  echo Verifiying/Installing %1
  %npm% install %1 -g
GOTO :EOF

:doNodeInstall
  if not exist "%NVM_DIR%\nvm.exe" (
    echo Downloading NVM...
    %uwget% --no-check-certificate https://github.com/coreybutler/nvm-windows/releases/download/1.0.6/nvm-noinstall.zip -O "%RUN_PATH%\nvm.zip"
    %uunzip% "%RUN_PATH%\nvm.zip" -d "%NVM_DIR%" >NUL
    DEL "%RUN_PATH%\nvm.zip" 2>NUL
  )
  echo root: %NVM_HOME% > "%NVM_DIR%\settings.txt"
  echo path: %NVM_SYMLINK% >> "%NVM_DIR%\settings.txt"
  echo arch: %OSBIT% >> "%NVM_DIR%\settings.txt"
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

:startMachineAgent
  echo Starting Machine Agent...
  CALL :writeControllerInfo "%RUN_PATH%\MachineAgent\conf\controller-info.xml"
  start "_AppDynamicsSampleApp_ Machine Agent" /MIN "%JAVA_HOME%\bin\java.exe" -jar %RUN_PATH%\MachineAgent\machineagent.jar
GOTO :EOF

:startDatabaseAgent
  echo Starting Database Agent...
  CALL :writeControllerInfo "%RUN_PATH%\DatabaseAgent\conf\controller-info.xml"
  start "_AppDynamicsSampleApp_ Database Agent" /MIN "%JAVA_HOME%\bin\java.exe" -Dappdynamics.controller.hostName=%CONTROLLER_ADDRESS% -Dappdynamics.controller.port=%CONTROLLER_PORT% -Dappdynamics.controller.ssl.enabled=%SSL% -Dappdynamics.agent.accountName=%ACCOUNT_NAME% -Dappdynamics.agent.accountAccessKey=%ACCOUNT_ACCESS_KEY% -jar %RUN_PATH%\DatabaseAgent\db-agent.jar
GOTO :EOF

:startup
  if %CONTROLLER_ADDRESS%==false echo No Controller Address Specified! & GOTO :usage
  if %CONTROLLER_PORT%==false echo No Controller Port Specified! & GOTO :usage
  CALL :about
  if not %PROMPT_EACH_REQUEST% == true (
    CALL :verifyUserAgreement "Do you agree to install all of the required dependencies if they do not exist and continue?"
    SET NOPROMPT=true
  )
  CALL :downloadWget
  CALL :downloadDependencies
  CALL :determineInstallPath
  IF %INSTALL_PATH% == Java (
    CALL :verifyJava
    CALL :doTomcatInstall
    CALL :doJavaAgentInstalls
  ) else (
    CALL :verifyNET
    CALL :setupNET
  )
  CALL :doMySqlInstall
  CALL :startMySql
  CALL :doNodeInstall
  CALL :startMachineAgent
  CALL :startDatabaseAgent
  IF %INSTALL_PATH% == Java (
    CALL :startTomcat
  ) else (
    CALL :startNET
  )
  CALL :startNode

  echo The AppDynamics Sample App Environment has been started.
  echo Please wait a few moments for the environment to initialize then:
  echo Visit http://localhost:%HTTP_PORT%
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
  IF %INSTALL_PATH% == NET (
    IF exist "%iis%" %iis% stop site "AppDemo .NET REST Server"
  )
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
  for /f "delims=(/ tokens=2" %%Y in ('"copy /-y nul ExitBatchYes.txt <nul"') do if not defined yes set "yes=%%Y"
  echo %yes%>ExitBatchYes.txt
  popd
GOTO :EOF