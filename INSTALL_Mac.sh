#!/bin/bash

# Configure these values on download.
ACCOUNT_NAME="config-account-name"
ACCOUNT_ACCESS_KEY="config-account-access-key"
CONTROLLER_ADDRESS="config-controller-host"
CONTROLLER_PORT="config-controller-port"
CONTROLLER_SSL="config-controller-ssl-enabled"
NODE_AGENT_VERSION="config-nodejs-agent-version"

# Mac-specific Config
PLATFORM="Mac"
export JAVA_HOME=$(/usr/libexec/java_home)
pushd `dirname $0` > /dev/null
SCRIPT_DIR=`pwd -P`
popd > /dev/null


####  ALL FOLLOWING CODE SHARED BETWEEN LINUX AND MAC  ####

# Protect against unset nodejs agent version as this is non-configurable via script parameters
if [ "$NODE_AGENT_VERSION" = "config-nodejs-agent-version" ]; then
  NODE_AGENT_VERSION="4.0.4"
fi

JAVA_PORT=8887
NODE_PORT=8888
DB_NAME="appd_sample_db"
DB_USER="appd_sample_user"
DB_PORT=8889
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
if [ "${NODE_AGENT_VERSION%?.*.*.*}" != "$NODE_AGENT_VERSION" ]; then
  NODE_AGENT_VERSION="${NODE_AGENT_VERSION%.*}"
fi

RUN_PATH="$SCRIPT_DIR/build"
mkdir -p "$RUN_PATH"; mkdir -p "$RUN_PATH/log"; cd "$RUN_PATH"
NOW=$(date +"%s")
RUN_LOG="$RUN_PATH/log/$NOW"
mkdir -p "$RUN_LOG"

export APPD_DB_FILE="$RUN_PATH/db"
export APPD_TOMCAT_FILE="$RUN_PATH/tomcat"

about() {
  cat "$SCRIPT_DIR/README"
}

usage() {
  echo ""
  printf "%s" "usage: sh $SCRIPT_NAME "
  cat "$SCRIPT_DIR/usage"
  exit 0
}

removeEnvironment() {
  echo "Removing Sample Application environment..."
  rm -rf "$RUN_PATH"
  echo "Done"
  exit 0
}

if [ $(id -u) = 0 ]; then echo "Do not run this script as root!"; usage; fi
if [ ! -w "$RUN_PATH" ]; then echo "The build directory is not writable, exiting."; exit 1; fi
while getopts :c:p:u:k:s:n:j:m:hydzt: OPT; do
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
  echo ""
  if ! ${PROMPT_EACH_REQUEST} ; then
    verifyUserAgreement "Do you agree to install all of the required dependencies if they do not exist and continue?"
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
  if ! command -v "$INSTALL_FILE" 2>/dev/null >/dev/null ; then echo "$INSTALL_FILE is required before this script can be executed. Exiting."; exit 1; fi
  return 0
}

installDependencies() {
  verifyDependency "curl"
  verifyDependency "unzip"
  verifyDependency "gcc"
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
  performTomcatDependencyDownload "org/apache/tomcat/embed/tomcat-embed-logging-juli/7.0.57/tomcat-embed-logging-juli-7.0.57.jar"
  performTomcatDependencyDownload "org/apache/tomcat/embed/tomcat-embed-jasper/7.0.57/tomcat-embed-jasper-7.0.57.jar"
  performTomcatDependencyDownload "org/apache/tomcat/embed/tomcat-embed-el/7.0.57/tomcat-embed-el-7.0.57.jar"
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
  startProcess "Tomcat" "Tomcat Server (Port $JAVA_PORT)" "sh tomcatrest/bin/SampleAppServer.sh" "INFO: Starting ProtocolHandler [\"http-bio-$JAVA_PORT\"]" "SEVERE: Failed to initialize"
}

installNode() {
  echo "Checking Node..."
  local URL_REF="linux"; local VERSION="x86"
  if [ "$PLATFORM" = "Mac" ]; then URL_REF="darwin"; fi
  if [ "$ARCH" = "x86_64" ]; then VERSION="x64"; fi

  NODE_DIR="$RUN_PATH/node-v$NODE_VERSION-$URL_REF-$VERSION"

  if [ ! -f "$NODE_DIR/bin/node" ]; then
    verifyUserAgreement "Node (v$NODE_VERSION) needs to be downloaded. Do you wish to continue?"
    local DOWNLOAD_URL="http://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$URL_REF-$VERSION.tar.gz"

    curl -L -o "$RUN_PATH/nodejs.tar.gz" "$DOWNLOAD_URL"
    gunzip -c "$RUN_PATH/nodejs.tar.gz" | tar xopf -
    rm "$RUN_PATH/nodejs.tar.gz"
  fi

  installNodeDependency "Express" "express" "4.12.3"
  installNodeDependency "Request" "request" "2.55.0"
  installNodeDependency "AppDynamics Agent" "appdynamics" "$NODE_AGENT_VERSION"
}

installNodeDependency() {
  local DEPENDENCY_NAME="$1"; local DEPENDENCY_INSTALL="$2"; local DEPENDENCY_VERSION="$3"

  echo "Checking $DEPENDENCY_NAME for Node.js..."
  if [ ! -f "$NODE_DIR/lib/node_modules/$DEPENDENCY_INSTALL/package.json" ]; then
    "$NODE_DIR/bin/npm" install -g "$DEPENDENCY_INSTALL@$DEPENDENCY_VERSION"
  else echo "Already installed."; fi
}

verifyPostgreSQL() {
  echo "Checking PostgreSQL..."
  POSTGRES_DIR="$RUN_PATH/pgsql"
  if [ ! -f "$POSTGRES_DIR/bin/psql" ]; then
    echo "Downloading PostgreSQL..."
    if [ "$PLATFORM" = "Linux" ]; then
      local VERSION=
      if [ "$ARCH" = "x86_64" ]; then VERSION="x64-"; fi
      local DOWNLOAD_URL="http://get.enterprisedb.com/postgresql/postgresql-9.4.1-3-linux-${VERSION}binaries.tar.gz"
      curl -L -o "$RUN_PATH/postgresql.tar.gz" "$DOWNLOAD_URL"
      echo "Unpacking PostgreSQL..."
      gunzip -c "$RUN_PATH/postgresql.tar.gz" | tar xopf -
      rm "$RUN_PATH/postgresql.tar.gz"
    elif [ "$PLATFORM" = "Mac" ]; then
      local DOWNLOAD_URL="http://get.enterprisedb.com/postgresql/postgresql-9.4.1-3-osx-binaries.zip"
      curl -L -o "$RUN_PATH/postgresql.zip" "$DOWNLOAD_URL"
      echo "Unpacking PostgreSQL..."
      unzip -d "$RUN_PATH/" "$RUN_PATH/postgresql.zip" >/dev/null
      rm "$RUN_PATH/postgresql.zip"
    else
      echo "Invalid platform setting. Exiting."
      exit 1
    fi
  fi

  "$POSTGRES_DIR/bin/initdb" -D "$POSTGRES_DIR/data"
  if ! "$POSTGRES_DIR/bin/pg_ctl" -D "$POSTGRES_DIR/data" start -l "$RUN_LOG/psql" -w -o "-p $DB_PORT" ; then
    echo "Error with the PostgreSQL Database. Exiting."
    exit 1
  fi
}

writeDbFile() {
  local DATABASE="$1"
  echo "$DATABASE" > "$APPD_DB_FILE"
  echo "$DB_PORT" >> "$APPD_DB_FILE"
  echo "$DB_NAME" >> "$APPD_DB_FILE"
  echo "$DB_USER" >> "$APPD_DB_FILE"
}

createPostgreSQLDatabase() {
  "$POSTGRES_DIR/bin/createdb" -p "$DB_PORT" "$DB_NAME"  2>/dev/null
  "$POSTGRES_DIR/bin/createuser" -p "$DB_PORT" -s "$DB_USER" 2>/dev/null
  "$POSTGRES_DIR/bin/psql" -U "$DB_USER" -p "$DB_PORT" -d "$DB_NAME" -f "$SCRIPT_DIR/src/sql/postgresql.sql" 2>/dev/null
  writeDbFile "postgresql"
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

startMachineAgent() {
  writeControllerInfo "$RUN_PATH/MachineAgent/conf/controller-info.xml"
  startProcess "machine-agent" "AppDynamics Machine Agent" "java -jar MachineAgent/machineagent.jar" "NOWAIT"
}

startDatabaseAgent() {
  writeControllerInfo "$RUN_PATH/DatabaseAgent/conf/controller-info.xml"
  startProcess "database-agent" "AppDynamics Database Agent" "java -jar DatabaseAgent/db-agent.jar" "NOWAIT"
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
  echo "var node = $NODE_PORT;" >> "$RUN_PATH/node/server.js"
  echo "var java = $JAVA_PORT;" >> "$RUN_PATH/node/server.js"
  cat "$SCRIPT_DIR/src/server.js" >> "$RUN_PATH/node/server.js"
  if [ ! -h "$RUN_PATH/node/public" ]; then ln -s "$SCRIPT_DIR/src/public/" "$RUN_PATH/node/public"; fi
  startProcess "node" "Node server (port $NODE_PORT)" "$NODE_DIR/bin/node $RUN_PATH/node/server.js" "Node Server Started" "Error:"
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
    rm -rf "$APPD_DB_FILE"
  fi
  cd "$SCRIPT_DIR"
  kill 0
}
trap "exit" INT TERM && trap onExitCleanup EXIT

startup
installDependencies
verifyJava
verifyPostgreSQL
createPostgreSQLDatabase
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
if [ "$PLATFORM" = "Linux" ]; then
  echo "Opening web browser to:  $SAMPLE_APP_URL"
  xdg-open "$SAMPLE_APP_URL" >/dev/null 2>&1
elif [ "$PLATFORM" = "Mac" ]; then
  echo "Opening web browser to:  $SAMPLE_APP_URL"
  open "$SAMPLE_APP_URL" >/dev/null 2>&1
else
  echo "To continue, please navigate your web browser to:  $SAMPLE_APP_URL"
fi

echo ""
echo "Press Ctrl-C to quit the sample app server and clean up..."
while true; do
  sleep 1
done
