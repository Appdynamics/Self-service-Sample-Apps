#!/bin/bash

# Configure these values on download.
ACCOUNT_NAME="config-account-name"
ACCOUNT_ACCESS_KEY="config-account-access-key"
CONTROLLER_ADDRESS="config-controller-host"
CONTROLLER_PORT="config-controller-port"
CONTROLLER_SSL="config-controller-ssl-enabled"
# NODE_AGENT_VERSION="config-nodejs-agent-version"
NODE_AGENT_VERSION="4.0.4"

# Linux-specific config
PLATFORM="Linux"
SCRIPT_DIR="$(readlink -f "$0" | xargs dirname)"


####  ALL FOLLOWING CODE SHARED BETWEEN LINUX AND MAC  ####

JAVA_PORT=8887
NODE_PORT=8888
DB_NAME=AppDemo
DB_PORT=
POSTGRES_DIR=
NODE_VERSION="0.10.33"
NOPROMPT=false
PROMPT_EACH_REQUEST=false
TIMEOUT=150
APP_STARTED=false
ARCH=$(uname -m)

APPLICATION_NAME="AppDynamics Sample App ($PLATFORM)"
SCRIPT_NAME="INSTALL_$PLATFORM.sh"

# Remove fourth number from Node agent version.
if [ "${NODE_AGENT_VERSION%?.*.*.*}" != $NODE_AGENT_VERSION ]; then
  NODE_AGENT_VERSION="${NODE_AGENT_VERSION%.*}"
fi

RUN_PATH="$SCRIPT_DIR"
mkdir -p "$RUN_PATH"; mkdir -p "$RUN_PATH/log"; cd "$RUN_PATH"
NOW=$(date +"%s")
RUN_LOG="$RUN_PATH/log/$NOW"
mkdir -p "$RUN_LOG"
export NVM_DIR="$RUN_PATH/.nvm"
mkdir -p "$NVM_DIR"

export APPD_DB_PORT_FILE="$RUN_PATH/db.port"
export APPD_TOMCAT_FILE="$RUN_PATH/tomcat"

about() {
  echo "
The following packages will be installed and configured:

  - Apache Tomcat Standalone Instance
  - AppDynamics App Agent for Java
  - AppDynamics Database Agent
  - AppDynamics Machine Agent
  - AppDynamics Node Agent
  - Node.js (with nvm, npm, Express, and Request)
  - PostgreSQL

Note: Your system must already have the following commands: curl, unzip
"
}

usage() {
  echo ""
  printf "%s" "usage: sudo sh $SCRIPT_NAME "
  cat "$SCRIPT_DIR/usage"
  exit 0
}

removeEnvironment() {
  echo "Removing Sample Application environment..."
  rm -rf "$NVM_DIR"
  rm -rf "$RUN_PATH/node"
  rm -rf "$RUN_PATH/AppServerAgent"
  rm -rf "$RUN_PATH/DatabaseAgent"
  rm -rf "$RUN_PATH/MachineAgent"
  rm -rf "$RUN_PATH/tomcatrest"
  rm -rf "$RUN_PATH/log"
  rm -rf "$RUN_PATH/node_modules"
  rm -rf "$RUN_PATH/pgsql"
  echo "Done"
  exit 0
}

while getopts :c:p:u:k:s:n:a:m:hdyzt: OPT; do
  case "$OPT" in
    c) CONTROLLER_ADDRESS=$OPTARG;;
    p) CONTROLLER_PORT=$OPTARG;;
    u) ACCOUNT_NAME=$OPTARG;;
    k) ACCOUNT_ACCESS_KEY=$OPTARG;;
    s) CONTROLLER_SSL=$OPTARG;;
    n) NODE_PORT=$OPTARG;;
    j) JAVA_PORT=$OPTARG;;
    m) DB_PORT=$OPTARG;;
    h) usage;;
    y) NOPROMPT=true;;
    d) removeEnvironment;;
    z) PROMPT_EACH_REQUEST=true;;
    t) TIMEOUT=$OPTARG;;
    :) echo "Missing argument for -$OPTARG!"; usage;;
    \?) echo "Invalid option: -$OPTARG!"; usage;;
  esac
done

verifyUserAgreement() {
  if [ "$2" != true ]; then
    if ${NOPROMPT} ; then return 0; fi
  fi
  local RESPONSE=
  while true; do
    read -p "$1 (y/n) " RESPONSE
    case "$RESPONSE" in
      [Yy]* ) break;;
      [Nn]* ) echo "Exiting."; exit;;
    esac
  done
  echo ""
}

startup() {
  about
  if ! ${PROMPT_EACH_REQUEST} ; then
    verifyUserAgreement "Continue to install above dependencies?"
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
    while [ "$LOOPS" -ne "$TIMEOUT" -a -n "$(ps -p"$APPD_ACTIVE_STARTUP_CHECK" -o pid=)" ]; do
      printf "%s" "."
      LOOPS=$((LOOPS+1))
      sleep 1
    done
    echo ""
    if [ "$(head -n 1 "$RUN_PATH/status-$LOG_KEY")" != "$LOG_SUCCESS_TEXT" -o "$LOOPS" -eq "$TIMEOUT" ]; then
      echo "Unable to start $PROCESS_NAME. Exiting."
      exit 1
    fi
    echo "$PROCESS_NAME started."
    rm "$RUN_PATH/status-$LOG_KEY"
  fi
}

verifyDependency() {
  local INSTALL_FILE="$1"
  if ! which "$INSTALL_FILE" >/dev/null ; then echo "$INSTALL_FILE is required before this script can be executed. Exiting."; exit 1; fi
  return 0
}

installDependencies() {
  verifyDependency "curl"
  verifyDependency "unzip"
}

LOGGED_IN=false
agentInstall() {
  local AGENT_NAME=$1; AGENT_DIR=$2; local AGENT_CHECK_FILE=$3; local AGENT_FILENAME=$4
  echo "Installing AppDynamics $AGENT_NAME... "
  if [ -f "$RUN_PATH/$AGENT_DIR/$AGENT_CHECK_FILE" ]; then echo "Already installed."; return 0; fi
  mkdir -p "$RUN_PATH/$AGENT_DIR"
  echo "Unpacking AppDynamics $AGENT_NAME (this may take a few minutes)..."
  unzip "$SCRIPT_DIR/agents/$AGENT_FILENAME" -d "$RUN_PATH/$AGENT_DIR" >/dev/null
  echo "Finished unpacking AppDynamics $AGENT_NAME."
}

installAgents() {
  agentInstall "App Agent for Java" "AppServerAgent" "javaagent.jar" "appdynamics-java-agent.zip"
  agentInstall "Database Agent" "DatabaseAgent" "db-agent.jar" "appdynamics-database-agent.zip"
  agentInstall "Machine Agent" "MachineAgent" "machineagent.jar" "appdynamics-machine-agent.zip"
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
  performTomcatDependencyDownload "org/postgresql/postgresql/9.4-1200-jdbc41/postgresql-9.4-1200-jdbc41.jar"
  performTomcatDependencyDownload "com/github/dblock/waffle/waffle-jna/1.7/waffle-jna-1.7.jar"
  performTomcatDependencyDownload "net/java/dev/jna/jna/4.1.0/jna-4.1.0.jar"
  performTomcatDependencyDownload "net/java/dev/jna/jna-platform/4.1.0/jna-platform-4.1.0.jar"
  performTomcatDependencyDownload "org/slf4j/slf4j-api/1.7.7/slf4j-api-1.7.7.jar"
  performTomcatDependencyDownload "com/google/guava/guava/18.0/guava-18.0.jar"
  performTomcatDependencyDownload "org/slf4j/slf4j-simple/1.7.7/slf4j-simple-1.7.7.jar"
}

startTomcat() {
  writeControllerInfo "$RUN_PATH/AppServerAgent/conf/controller-info.xml" "JavaServer" "JavaServer01"
  for dir in "$RUN_PATH/AppServerAgent/ver"* ; do
    writeControllerInfo "$dir/conf/controller-info.xml" "JavaServer" "JavaServer01"
  done
  export JAVA_OPTS="-javaagent:$RUN_PATH/AppServerAgent/javaagent.jar"
  startProcess "Tomcat" "Tomcat Server (Port $JAVA_PORT)" "sh $RUN_PATH/tomcatrest/bin/SampleAppServer.sh" "INFO: Starting ProtocolHandler [\"http-bio-$JAVA_PORT\"]" "ERROR:"
}

setupNodeNvm() {
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

installNodeDependency() {
  local DEPENDENCY_NAME="$1"; local DEPENDENCY_INSTALL="$2"; local DEPENDENCY_VERSION="$3"

  echo "Installing $DEPENDENCY_NAME for Node.js..."
  if ! "$NVM_DIR/v$NODE_VERSION/bin/npm" list "$DEPENDENCY_INSTALL" >/dev/null ; then
    "$NVM_DIR/v$NODE_VERSION/bin/npm" install "$DEPENDENCY_INSTALL@$DEPENDENCY_VERSION"
  else echo "Already installed."; fi
}

installNode() {
  echo "Installing Node..."
  setupNodeNvm
  if ! command -v nvm 2>/dev/null >/dev/null ; then
    verifyUserAgreement "Node needs to be downloaded. Do you wish to continue?"
    curl https://raw.githubusercontent.com/creationix/nvm/v0.23.3/install.sh | NVM_DIR="$NVM_DIR" sh;

    echo "Initializing nvm automatically..."
    setupNodeNvm
  fi
  nvm install "$NODE_VERSION"

  installNodeDependency "Express" "express" "4.12.3"
  installNodeDependency "Request" "request" "2.55.0"
  installNodeDependency "AppDynamics Agent" "appdynamics" "$NODE_AGENT_VERSION"
}

getDatabaseChoice() {
  # local RESPONSE=
  # while true; do
  #   echo "Choose database to use with this sample app:"
  #   echo "  1. Use an existing PostgreSQL server instance."
  #   echo "  2. Download and install separate PostgreSQL server instance."
  #   echo "  3. Quit this installer."
  #   read -p "Enter your choice: " RESPONSE
  #   case "$RESPONSE" in
  #     [1]* ) DB_CHOICE="existing"; break;;
  #     [2]* ) DB_CHOICE="install"; break;;
  #     [3]* ) echo "Exiting."; exit;;
  #   esac
  # done
  DB_CHOICE="install"
}

verifyMySQL() {
  printf "Checking MySQL..."
  if ! which mysql >/dev/null ; then
    echo ""
    echo "Cannot find mysql. Please make sure it is installed and in your PATH. Exiting."
    exit 1
  fi
  if [ "$DB_PORT" == "" ]; then
    DB_PORT=3306
  fi
  echo " done."
}

verifyPostgreSQL() {
  echo "Checking PostgreSQL..."
  POSTGRES_DIR="$RUN_PATH/pgsql"
  if [ ! -f "$POSTGRES_DIR/bin/psql" ]; then
    echo "Downloading PostgreSQL..."
    if [ $PLATFORM == "Linux" ]; then
      local VERSION=
      if [ "$ARCH" = "x86_64" ]; then VERSION="x64-"; fi
      local DOWNLOAD_URL="http://get.enterprisedb.com/postgresql/postgresql-9.4.1-3-linux-${VERSION}binaries.tar.gz"
      curl -L -o "$RUN_PATH/postgresql.tar.gz" "$DOWNLOAD_URL"
      echo "Unpacking PostgreSQL..."
      gunzip -c "$RUN_PATH/postgresql.tar.gz" | tar xopf -
      rm "$RUN_PATH/postgresql.tar.gz"
    elif [ $PLATFORM == "Mac" ]; then
      local DOWNLOAD_URL="http://get.enterprisedb.com/postgresql/postgresql-9.4.1-3-osx-binaries.zip"
      curl -L -o "$RUN_PATH/postgresql.zip" "$DOWNLOAD_URL"
      echo "Unpacking PostgreSQL..."
      unzip -d "$RUN_PATH/" "$RUN_PATH/postgresql.zip"
      rm "$RUN_PATH/postgresql.zip"
    else
      echo "Invalid platform setting. Exiting."
      exit 1
    fi
  fi

  # Start PostgreSQL
  if [ "$DB_PORT" == "" ]; then
    DB_PORT=5439
  fi
  "$POSTGRES_DIR/bin/initdb" -D "$POSTGRES_DIR/data"
  if ! "$POSTGRES_DIR/bin/pg_ctl" -D "$POSTGRES_DIR/data" start -l "$RUN_LOG/psql" -w -o "-p $DB_PORT" ; then
    echo "Error with the PostgreSQL Database. Exiting."
    exit 1
  fi
}

createPostgreSQLDatabase() {
  "$POSTGRES_DIR/bin/createdb" -p "$DB_PORT" $DB_NAME  2>/dev/null
  "$POSTGRES_DIR/bin/createuser" -p "$DB_PORT" -s demouser  2>/dev/null
  "$POSTGRES_DIR/bin/psql" -U demouser -p "$DB_PORT" -d $DB_NAME -f "$RUN_PATH/src/sql/postgresql.sql" 2>/dev/null
  echo "postgresql" > "$APPD_DB_PORT_FILE"
  echo "$DB_PORT" >> "$APPD_DB_PORT_FILE"
}

verifyJava() {
  printf "Checking Java..."
  if [ ! -f "$JAVA_HOME/bin/java" ]; then
    echo ""
    echo "Cannot find java. Please make sure JAVA_HOME is configured properly. Exiting."
    exit 1;
  fi
  echo " done."
}

createMySQLDatabase() {
  echo ""
  echo "Please enter your MySQL root password to install the sample app database."
  mysql -u root -p < "$SCRIPT_DIR/src/sql/mysql.sql"
  if [ $? -ne 0 ]; then
    verifyUserAgreement "The mysql script install/check failed. Do you wish to try again?" true
    createMySQLDatabase
  fi
  echo "mysql" > "$APPD_DB_PORT_FILE"
  echo "$DB_PORT" >> "$APPD_DB_PORT_FILE"
  echo ""
  return 0
}

startMachineAgent() {
  writeControllerInfo "$RUN_PATH/MachineAgent/conf/controller-info.xml"
  startProcess "machine-agent" "AppDynamics Machine Agent" "java -jar $RUN_PATH/MachineAgent/machineagent.jar" "NOWAIT"
}

startDatabaseAgent() {
  writeControllerInfo "$RUN_PATH/DatabaseAgent/conf/controller-info.xml"
  startProcess "database-agent" "AppDynamics Database Agent" "java -jar $RUN_PATH/DatabaseAgent/db-agent.jar" "NOWAIT"
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
  if [ ! -h "$RUN_PATH/node/public" ]; then ln -s "$SCRIPT_DIR/src/public/" "$RUN_PATH/node/public"; fi
  startProcess "node" "Node server (port $NODE_PORT)" "$NVM_DIR/v$NODE_VERSION/bin/node $RUN_PATH/node/server.js" "Node Server Started" "\"Error\":"
}

generateInitialLoad() {
  local LOAD_HITS=10
  for LOOPS in $(seq 1 "$LOAD_HITS")
  do
    echo "Generating app load: request $LOOPS of $LOAD_HITS..."
    curl "http://localhost:$NODE_PORT/retrieve?id=1" 2>/dev/null >/dev/null
    sleep 1
  done
}

onExitCleanup() {
  trap - TERM; stty echo
  echo ""
  if ${APP_STARTED} ; then
    echo "Killing all processes and cleaning up..."
    "$RUN_PATH/pgsql/bin/pg_ctl" -D "$RUN_PATH/pgsql/data" stop -m i 2>/dev/null
    rm -rf "$RUN_PATH/cookies"
    rm -rf "$RUN_PATH/status-"*
    rm -rf "$APPD_TOMCAT_FILE"
    rm -rf "$APPD_DB_PORT_FILE"
  fi
  kill 0
}
trap "exit" INT TERM && trap onExitCleanup EXIT

startup
installDependencies
verifyJava
getDatabaseChoice
if [ "$DB_CHOICE" = "install" ]; then
  verifyPostgreSQL
  createPostgreSQLDatabase
fi
installTomcat
installNode
installAgents
startMachineAgent
startDatabaseAgent
startTomcat
startNode
generateInitialLoad

echo ""
echo "Success!  The AppDynamics sample application is ready."

SAMPLE_APP_URL="http://localhost:$NODE_PORT"
if [ $PLATFORM == "Linux" ]; then
  echo "Opening web browser to:  $SAMPLE_APP_URL"
  xdg-open $SAMPLE_APP_URL
elif [ $PLATFORM == "Mac" ]; then
  echo "Opening web browser to:  $SAMPLE_APP_URL"
  open $SAMPLE_APP_URL
else
  echo "To continue, please navigate your web browser to:  $SAMPLE_APP_URL"
fi

echo ""
echo "Press Ctrl-C to quit the sample app server and clean up..."
while true; do
  sleep 1
done
