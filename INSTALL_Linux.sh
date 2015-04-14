#!/bin/bash

# Configure these values on download.
ACCOUNT_NAME="config-account-name"
ACCOUNT_ACCESS_KEY="config-account-access-key"
CONTROLLER_ADDRESS="config-controller-host"
CONTROLLER_PORT="config-controller-port"
CONTROLLER_SSL="config-controller-ssl-enabled"
DATABASE_AGENT_VERSION="4.0.1.0"
JAVA_AGENT_VERSION="4.0.1.0"
MACHINE_AGENT_VERSION="4.0.1.0"
NODE_AGENT_VERSION="4.0.1"
DOWNLOAD_HOSTNAME="download.appdynamics.com"

APPLICATION_NAME="AppDynamics Sample App (Linux)"
JAVA_PORT=8887
NODE_PORT=8888
MYSQL_PORT=3306
AXIS_VERSION="1.6.2"
ANT_VERSION="1.9.4"
NODE_VERSION="0.10.33"
NOPROMPT=false
PROMPT_EACH_REQUEST=false
TIMEOUT=150
APP_STARTED=false

SCRIPT_DIR="$(readlink -f "$0" | xargs dirname)"

RUN_PATH="/var/tmp/AppDynamicsSampleApp"
mkdir -p "$RUN_PATH"; mkdir -p "$RUN_PATH/log"; cd "$RUN_PATH"
NOW=$(date +"%s")
RUN_LOG="$RUN_PATH/log/$NOW"
mkdir -p "$RUN_LOG"
export NVM_DIR="$RUN_PATH/.nvm"
AXIS_DIR="axis2-$AXIS_VERSION"
export AXIS2_HOME="$RUN_PATH/$AXIS_DIR"
ANT_DIR="apache-ant-$ANT_VERSION"
export ANT_HOME="$RUN_PATH/$ANT_DIR"

export APPD_MYSQL_PORT_FILE="$RUN_PATH/mysql.port"
export APPD_TOMCAT_FILE="$RUN_PATH/tomcat"

about() {
  cat "$SCRIPT_DIR/README"
  echo "
* Note The following dependencies are required:
  - curl
  - unzip
"
}

usage() {
  about
  printf "%s" "usage: sudo sh Appdemo.sh "
  cat "$SCRIPT_DIR/usage"
  exit 0
}

removeEnvironment() {
  echo "Removing Sample Application environment..."
  rm -rf "$RUN_PATH"
  echo "Done"
  exit 0
}

if ! [ $(id -u) = 0 ]; then echo "Please run this script as root!"; usage; fi
while getopts :c:p:u:k:s:n:a:m:hdyzt: OPT; do
  case "$OPT" in
    c) CONTROLLER_ADDRESS=$OPTARG;;
    p) CONTROLLER_PORT=$OPTARG;;
    u) ACCOUNT_NAME=$OPTARG;;
    k) ACCOUNT_ACCESS_KEY=$OPTARG;;
    s) CONTROLLER_SSL=$OPTARG;;
    n) NODE_PORT=$OPTARG;;
    j) JAVA_PORT=$OPTARG;;
    m) MYSQL_PORT=$OPTARG;;
    h) usage;;
    y) NOPROMPT=true;;
    d) removeEnvironment;;
    z) PROMPT_EACH_REQUEST=true;;
    t) TIMEOUT=$OPTARG;;
    :) echo "Missing argument for -$OPTARG!"; usage;;
    \?) echo "Invalid option: -$OPTARG!"; usage;;
  esac
done

if [ ${CONTROLLER_ADDRESS} = false ]; then
  echo "No Controller Address Specified!"; usage
fi
if [ ${CONTROLLER_PORT} = false ]; then
  echo "No Controller Port Specified!"; usage
fi

verifyUserAgreement() {
  if [ "$2" != true ]; then
    if ${NOPROMPT} ; then return 0; fi
  fi
  echo "$1"
  local RESPONSE=
  while [ "$RESPONSE" != "Y" ]
  do
    read -p "Please input \"Y\" to accept, or \"n\" to decline and quit: " RESPONSE
    if [ "$RESPONSE" = "n" ]; then exit 1; fi
  done
}

startup() {
  about
  if ! ${PROMPT_EACH_REQUEST} ; then
    verifyUserAgreement "Do you agree to install all of the required dependencies if they do not exist and continue?
      (If you wish to be prompted before each operation run this script with the -z flag)"
    NOPROMPT=true
  fi
  APP_STARTED=true
}

escaper() {
  echo "$1" | sed 's/\([[$\/\:]\)/\\\1/g'
}

writeControllerInfo() {
  local WRITE_FILE="$1"; local TIER_NAME="$2"; local NODE_NAME="$3"
  printf "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<controller-info>
		<controller-host>%s</controller-host>
		<controller-port>%s</controller-port>
		<controller-ssl-enabled>%s</controller-ssl-enabled>
		<account-name>%s</account-name>
		<account-access-key>%s</account-access-key>
		<application-name>%s</application-name>
		<tier-name>%s</tier-name>
		<node-name>%s</node-name>
	</controller-info>
  " "$CONTROLLER_ADDRESS" "$CONTROLLER_PORT" "$CONTROLLER_SSL" "$ACCOUNT_NAME" "$ACCOUNT_ACCESS_KEY" "$APPLICATION_NAME" "$TIER_NAME" "$NODE_NAME" > "$WRITE_FILE"
}

startProcess() {
  local LOG_KEY="$1"; PROCESS_NAME="$2"; local PROCESS_COMMAND="$3"
  local LOG_SUCCESS_TEXT="$4"; local LOG_FAILURE_TEXT="$5"; local NOWAIT=false
  APPD_ACTIVE_STARTUP_CHECK=
  echo "Starting $PROCESS_NAME..."
  touch "$RUN_LOG/$LOG_KEY"
  if [ "$LOG_SUCCESS_TEXT" != "NOWAIT" ]; then
    tail -n 1 -f "$RUN_LOG/$LOG_KEY" | grep -m 1 "$(escaper "$LOG_SUCCESS_TEXT")\|$(escaper "$LOG_FAILURE_TEXT")" | { cat; echo >> "$RUN_LOG/$LOG_KEY"; } > "$RUN_PATH/status-$LOG_KEY" &
    APPD_ACTIVE_STARTUP_CHECK=$!
  else NOWAIT=true; fi;
  ${PROCESS_COMMAND} >> "$RUN_LOG/$LOG_KEY" 2>&1  &
  if [ "$NOWAIT" = false ]; then
    LOOPS=0
    while [ "$LOOPS" -ne "$TIMEOUT" -a $(ps -p"$APPD_ACTIVE_STARTUP_CHECK" -o pid=) ]; do
      printf "%s" "."
      LOOPS=$((LOOPS+1))
      sleep 1
    done
    echo ""
    if [ "$(head -n 1 "$RUN_PATH/status-$LOG_KEY")" != "$LOG_SUCCESS_TEXT" -o "$LOOPS" -eq "$TIMEOUT" ]; then
      echo "Unable to start $PROCESS_NAME, exiting."
      exit 1
    fi
    echo "$PROCESS_NAME Started"
    rm "$RUN_PATH/status-$LOG_KEY"
  fi
}

verifyDependency() {
  local INSTALL_FILE="$1"
  if ! which "$INSTALL_FILE" >/dev/null ; then echo "$INSTALL_FILE is required before this script can be executed, exiting."; exit 1; fi
  return 0
}

installDependencies() {
  verifyDependency "curl"
  verifyDependency "unzip"
}

LOGGED_IN=false
agentInstall() {
  local AGENT_DIR=$1; local AGENT_CHECK_FILE=$2; local AGENT_URL=$3
  echo "Verifying/Install AppDynamics $AGENT_DIR..."
  if [ -f "$RUN_PATH/$AGENT_DIR/$AGENT_CHECK_FILE" ]; then echo "INSTALLED"; return 0; fi
  mkdir -p "$RUN_PATH/$AGENT_DIR"
  if ! ${LOGGED_IN} ; then
    local USERNAME=""; local PASSWORD=""
    while ! grep -s -q login.appdynamics.com "$RUN_PATH/cookies"; do
      if [ -f "$RUN_PATH/cookies" ]; then echo "Invalid Username/Password"; else echo "Please Sign in order to download AppDynamics Agents"; fi
      read -p "Username: " USERNAME && stty -echo && read -p "Password: " PASSWORD && stty echo && echo
      curl -q -o /dev/null --cookie-jar "$RUN_PATH/cookies" --data "username=$USERNAME&password=$PASSWORD" --insecure "https://login.appdynamics.com/sso/login/"
    done
    LOGGED_IN=true
  fi
  curl -q -L -o "$RUN_PATH/$AGENT_DIR/$AGENT_DIR.zip" --cookie "$RUN_PATH/cookies" --insecure "$AGENT_URL"
  echo "Unpacking $AGENT_DIR (this may take a few minutes)..."
  unzip "$RUN_PATH/$AGENT_DIR/$AGENT_DIR.zip" -d "$RUN_PATH/$AGENT_DIR" >/dev/null; rm "$RUN_PATH/$AGENT_DIR/$AGENT_DIR.zip"
  if [ ! -f "$RUN_PATH/$AGENT_DIR/$AGENT_CHECK_FILE" ]; then echo "Bad Agent Archive: $AGENT_DIR.zip, exiting."; exit 1; fi
}

installAgents() {
  agentInstall "MachineAgent" "machineagent.jar" "https://$DOWNLOAD_HOSTNAME/saas/public/archives/$MACHINE_AGENT_VERSION/MachineAgent-$MACHINE_AGENT_VERSION.zip"
  agentInstall "DatabaseAgent" "db-agent.jar" "https://$DOWNLOAD_HOSTNAME/saas/public/archives/$DATABASE_AGENT_VERSION/dbagent-$DATABASE_AGENT_VERSION.zip"
  agentInstall "AppServerAgent" "javaagent.jar" "https://$DOWNLOAD_HOSTNAME/saas/public/archives/$JAVA_AGENT_VERSION/AppServerAgent-$JAVA_AGENT_VERSION.zip"
}

performTomcatDependencyDownload() {
  local TOMCAT_URL=$1
  if [ -f "$RUN_PATH/tomcatrest/repo/$TOMCAT_URL" ]; then return 0; fi
  echo "Downloading http://repo.maven.apache.org/maven2/$TOMCAT_URL"
  curl -q --create-dirs -L -o "$RUN_PATH/tomcatrest/repo/$TOMCAT_URL" "http://repo.maven.apache.org/maven2/$TOMCAT_URL"
}

installTomcat() {
  echo "Setting up Tomcat..."
  echo "$JAVA_PORT" > "$APPD_TOMCAT_FILE"
  mkdir -p "$RUN_PATH/tomcatrest/repo"
  mkdir -p "$RUN_PATH/tomcatrest/bin"
  cp -rf "$SCRIPT_DIR/sampleapp/"* "$RUN_PATH/tomcatrest" >/dev/null
  performTomcatDependencyDownload "org/glassfish/jersey/containers/jersey-container-servlet/2.10.1/jersey-container-servlet-2.10.1.jar"
  performTomcatDependencyDownload "org/glassfish/jersey/containers/jersey-container-servlet-core/2.10.1/jersey-container-servlet-core-2.10.1.jar"
  performTomcatDependencyDownload "org/glassfish/hk2/external/javax.inject/2.3.0-b05/javax.inject-2.3.0-b05.jar"
  performTomcatDependencyDownload "org/glassfish/jersey/core/jersey-common/2.10.1/jersey-common-2.10.1.jar"
  performTomcatDependencyDownload "javax/annotation/javax.annotation-api/1.2/javax.annotation-api-1.2.jar"
  performTomcatDependencyDownload "org/glassfish/jersey/bundles/repackaged/jersey-guava/2.10.1/jersey-guava-2.10.1.jar"
  performTomcatDependencyDownload "org/glassfish/hk2/hk2-api/2.3.0-b05/hk2-api-2.3.0-b05.jar"
  performTomcatDependencyDownload "org/glassfish/hk2/hk2-utils/2.3.0-b05/hk2-utils-2.3.0-b05.jar"
  performTomcatDependencyDownload "org/glassfish/hk2/external/aopalliance-repackaged/2.3.0-b05/aopalliance-repackaged-2.3.0-b05.jar"
  performTomcatDependencyDownload "org/glassfish/hk2/hk2-locator/2.3.0-b05/hk2-locator-2.3.0-b05.jar"
  performTomcatDependencyDownload "org/javassist/javassist/3.18.1-GA/javassist-3.18.1-GA.jar"
  performTomcatDependencyDownload "org/glassfish/hk2/osgi-resource-locator/1.0.1/osgi-resource-locator-1.0.1.jar"
  performTomcatDependencyDownload "org/glassfish/jersey/core/jersey-server/2.10.1/jersey-server-2.10.1.jar"
  performTomcatDependencyDownload "org/glassfish/jersey/core/jersey-client/2.10.1/jersey-client-2.10.1.jar"
  performTomcatDependencyDownload "javax/validation/validation-api/1.1.0.Final/validation-api-1.1.0.Final.jar"
  performTomcatDependencyDownload "javax/ws/rs/javax.ws.rs-api/2.0/javax.ws.rs-api-2.0.jar"
  performTomcatDependencyDownload "mysql/mysql-connector-java/5.1.6/mysql-connector-java-5.1.6.jar"
  performTomcatDependencyDownload "org/apache/tomcat/embed/tomcat-embed-logging-juli/7.0.57/tomcat-embed-logging-juli-7.0.57.jar"
  performTomcatDependencyDownload "org/apache/tomcat/embed/tomcat-embed-jasper/7.0.57/tomcat-embed-jasper-7.0.57.jar"
  performTomcatDependencyDownload "org/apache/tomcat/embed/tomcat-embed-el/7.0.57/tomcat-embed-el-7.0.57.jar"
  performTomcatDependencyDownload "org/eclipse/jdt/core/compiler/ecj/4.4/ecj-4.4.jar"
  performTomcatDependencyDownload "org/apache/tomcat/embed/tomcat-embed-core/7.0.57/tomcat-embed-core-7.0.57.jar"
}

startTomcat() {
  writeControllerInfo "$RUN_PATH/AppServerAgent/conf/controller-info.xml" "JavaServer" "JavaServer01"
  writeControllerInfo "$RUN_PATH/AppServerAgent/ver$JAVA_AGENT_VERSION/conf/controller-info.xml" "JavaServer" "JavaServer01"
  export JAVA_OPTS="-javaagent:$RUN_PATH/AppServerAgent/javaagent.jar"
  startProcess "Tomcat" "Tomcat Server (Port $JAVA_PORT)" "sh $RUN_PATH/tomcatrest/bin/SampleAppServer.sh" "INFO: Starting ProtocolHandler [\"http-bio-$JAVA_PORT\"]" "ERROR:"
}

setupNodeNvm() {
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

installNode() {
  echo "Verifying/Installing Node..."
  setupNodeNvm
  if ! command -v nvm 2>/dev/null >/dev/null ; then
    verifyUserAgreement "Node needs to be downloaded, do you wish to continue?"
    curl https://raw.githubusercontent.com/creationix/nvm/v0.23.3/install.sh | NVM_DIR="$NVM_DIR" sh;
    echo "Inititalizing nvm automatically..."
    setupNodeNvm
  fi
  nvm install 0.10.33

  echo "Verifying/Installing AppDynamics NodeJS Agent..."
  if ! npm list appdynamics >/dev/null ; then npm install "appdynamics@$NODE_AGENT_VERSION"; else echo "Installed"; fi

  echo "Verifying/Installing Node Express..."
  if ! npm list express >/dev/null ; then npm install express@4.12.3; else echo "Installed"; fi

  echo "Verifying/Installing Node Request..."
  if ! npm list request >/dev/null ; then npm install request@2.55.0; else echo "Installed"; fi

  echo "Verifying/Installing jQuery..."
  if ! npm list jquery >/dev/null ; then npm install jquery@2.1.3; else echo "Installed"; fi

  echo "Verifying/Installing Bootstrap..."
  if ! npm list bootstrap >/dev/null ; then npm install bootstrap@3.3.4; else echo "Installed"; fi

  echo "Verifying/Installing AngularJS..."
  if ! npm list angular >/dev/null ; then npm install angular@1.3.14; else echo "Installed"; fi
}

verifyMySQL() {
  echo "Verifying MySQL..."
  if ! which mysql >/dev/null ; then
    echo "Cannot find mysql, please make sure it is installed before continuing, exiting.";
    exit 1;
  fi
  echo "$MYSQL_PORT" > "$APPD_MYSQL_PORT_FILE"
}

verifyJava() {
  echo "Verifying Java..."
  if ! which java >/dev/null; then
    echo "Cannot find java, please make sure it is installed before continuing, exiting."
    exit 1;
  fi
}

createMySQLDatabase() {
  echo "Please login to mysql with root to setup the database for the demo application..."
  mysql -u root -p < "$SCRIPT_DIR/src/mysql.sql"
  if [ $? -ne 0 ]; then
    verifyUserAgreement "The mysql script install/check failed, do you wish to try again?" true
    createMySQLDatabase
  fi
  echo "$MYSQL_PORT" > "$APPD_MYSQL_PORT_FILE"
  return 0
}

startMachineAgent() {
  writeControllerInfo "$RUN_PATH/MachineAgent/conf/controller-info.xml"
  startProcess "MachineAgent" "Machine Agent" "java -jar $RUN_PATH/MachineAgent/machineagent.jar" "NOWAIT"
}

startDatabaseAgent() {
  writeControllerInfo "$RUN_PATH/DatabaseAgent/conf/controller-info.xml"
  startProcess "DatabaseAgent" "Database Agent" "java -Dappdynamics.controller.hostName=$CONTROLLER_ADDRESS -Dappdynamics.controller.port=$CONTROLLER_PORT -Dappdynamics.controller.ssl.enabled=$CONTROLLER_SSL -Dappdynamics.agent.accountName=$ACCOUNT_NAME -Dappdynamics.agent.accountAccessKey=$ACCOUNT_ACCESS_KEY -jar $RUN_PATH/DatabaseAgent/db-agent.jar" "NOWAIT"
}

startNode() {
  mkdir -p "$RUN_PATH/node"
  printf "
require(\"appdynamics\").profile({
    controllerHostName: \"%s\",
    controllerPort: %s,
    accountName: \"%s\",
    accountAccessKey: \"%s\",
    controllerSslEnabled: %s,
    applicationName: \"%s\",
    tierName: \"NodeServer\",
    nodeName: \"NodeServer01\"
});
  " "$CONTROLLER_ADDRESS" "$CONTROLLER_PORT" "$ACCOUNT_NAME" "$ACCOUNT_ACCESS_KEY" "$CONTROLLER_SSL" "$APPLICATION_NAME" > "$RUN_PATH/node/server.js"
  cat "$SCRIPT_DIR/src/server.js" >> "$RUN_PATH/node/server.js"
  ln -sf "$RUN_PATH/node_modules/angular/" "$SCRIPT_DIR/src/public/angular"
  ln -sf "$RUN_PATH/node_modules/bootstrap/dist/" "$SCRIPT_DIR/src/public/bootstrap"
  ln -sf "$RUN_PATH/node_modules/jquery/dist/" "$SCRIPT_DIR/src/public/jquery"
  if [ ! -h "$RUN_PATH/node/public" ]; then ln -s "$SCRIPT_DIR/src/public/" "$RUN_PATH/node/public"; fi
  startProcess "Node" "Node (Port $NODE_PORT)" "node $RUN_PATH/node/server.js" "Node Server Started" "\"Error\":"
}

onExitCleanup() {
  trap - TERM; stty echo
  echo ""
  if ${APP_STARTED} ; then
    echo "Killing all processes and cleaning up..."
    rm -f "$RUN_PATH/cookies"
    rm -f "$RUN_PATH/status-"*
    rm -f "$RUN_PATH/tomcat"
  fi
  kill 0
}
trap "exit" INT TERM && trap onExitCleanup EXIT

startup
installDependencies
verifyJava
verifyMySQL
createMySQLDatabase
installTomcat
installNode
installAgents
startMachineAgent
startDatabaseAgent
startTomcat
startNode

echo "Sample App Environment Setup Complete!"
echo "Visit http://localhost:$NODE_PORT to view the sample app."

read -p "Press [Enter] key to quit..." QUIT_VAR
