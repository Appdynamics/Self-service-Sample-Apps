#!/bin/bash

# Linux-specific config
PLATFORM="Linux"
SCRIPT_DIR="$(readlink -f "$0" | xargs dirname)"


####  ALL FOLLOWING CODE SHARED BETWEEN LINUX AND MAC  ####

# Configure these values on download.
ACCOUNT_NAME="config-account-name"
ACCOUNT_ACCESS_KEY="config-account-access-key"
CONTROLLER_ADDRESS="config-controller-host"
CONTROLLER_PORT="config-controller-port"
CONTROLLER_SSL="config-controller-ssl-enabled"
# NODE_AGENT_VERSION="config-nodejs-agent-version"
NODE_AGENT_VERSION="4.0.4"  # Keep at 4.0.4 until 4.1 Node agent is released.

# Remove fourth number from Node agent version.
if [ "${NODE_AGENT_VERSION%?.*.*.*}" != "$NODE_AGENT_VERSION" ]; then
  NODE_AGENT_VERSION="${NODE_AGENT_VERSION%.*}"
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

export APPD_DB_FILE="$SCRIPT_DIR/build/database"
export APPD_TOMCAT_FILE="$SCRIPT_DIR/build/tomcat"


main() {
  if [ $(id -u) = 0 ]; then echo "Do not run this script as root."; printUsageMessage; fi

  getOptions "$@"
  verifyCommands
  verifyJava
  promptUserDependencyInstall

  cd "$SCRIPT_DIR"
  trap "exit" INT TERM && trap onExitCleanup EXIT

  makeBuildDirectories
  installPostgreSQL
  createPostgreSQLDatabase
  installTomcat
  installNode
  installAgents
  startMachineAgent
  startDatabaseAgent
  startTomcat
  startNode
  generateInitialLoad
  printSuccessMessage
  waitForKill
}

getOptions() {
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
      h) printUsageMessage;;
      y) NOPROMPT=true;;
      d) removeEnvironment;;
      z) PROMPT_EACH_REQUEST=true;;
      t) TIMEOUT=$OPTARG;;
      :) echo "Missing argument for -$OPTARG!"; printUsageMessage;;
      \?) echo "Invalid option: -$OPTARG!"; printUsageMessage;;
    esac
  done
}

printUsageMessage() {
  echo ""
  printf "%s" "usage: sh $SCRIPT_NAME "
  cat "$SCRIPT_DIR/usage"
  exit 0
}

removeEnvironment() {
  echo "Removing Sample Application environment..."
  rm -rf "build"
  echo "Done"
  exit 0
}

promptUser() {
  if [ "$2" != true ]; then
    if ${NOPROMPT} ; then return 0; fi
  fi
  local RESPONSE=
  while true; do
    read -p "$1 (y/n) " RESPONSE
    case "$RESPONSE" in
      [Yy]* ) break;;
      [Nn]* ) exit;;
    esac
  done
  echo ""
}

escaper() {
  echo "$1" | sed 's/\([[$\/\:]\)/\\\1/g'
}

verifyCommands() {
  if [ "$PLATFORM" = "Linux" ]; then
    verifyLinuxCommand "curl"
    verifyLinuxCommand "gcc"
    verifyLinuxCommand "unzip"
  elif [ "$PLATFORM" = "Mac" ]; then
    verifyCommand "curl" "Download cURL from http://curl.haxx.se/download.html
Follow the instructions in the cURL package to install it."
    verifyCommand "gcc" "To install gcc, run:  xcode-select --install
Or download and install Xcode from the Mac App Store."
    verifyCommand "unzip" "Check that your PATH variable is set correctly."
  else
    echo "ERROR: Invalid platform setting."
    exit 1
  fi
}

verifyLinuxCommand() {
  local COMMAND="$1"
  verifyCommand "$COMMAND" "Run:  sudo apt-get install $COMMAND
Or:   sudo yum install $COMMAND"
}

verifyCommand() {
  local COMMAND="$1"; local INSTRUCTIONS="$2"
  if ! command -v "$COMMAND" 2>/dev/null >/dev/null ; then
    echo "ERROR: $COMMAND is required before continuing."
    if "$INSTRUCTIONS"; then echo "$INSTRUCTIONS"; fi
    exit 1; fi
  return 0
}

verifyJava() {
  if [ ! -f "$JAVA_HOME/bin/java" ]; then
    echo "ERROR: Cannot find java. Please make sure JAVA_HOME variable is set properly."
    exit 1;
  fi
}

promptUserDependencyInstall() {
  # Print short summary of what the script will do.  Do not cat README here.
  echo "
Welcome to the AppDynamics Sample App Installer.
The following dependencies will be installed:

  - Apache Tomcat Standalone Instance
  - AppDynamics App Agent for Java
  - AppDynamics Database Agent
  - AppDynamics Machine Agent
  - AppDynamics Node Agent
  - Node.js (with npm, Express, and Request)
  - PostgreSQL
"
  if ! ${PROMPT_EACH_REQUEST} ; then
    promptUser "Continue to install above dependencies?"
    NOPROMPT=true
  fi
  APP_STARTED=true
}

makeBuildDirectories() {
  mkdir -p "build"
  if [ ! -w "build" ]; then echo "ERROR: The build directory is not writable."; exit 1; fi

  mkdir -p "build/log"
  NOW=$(date +"%s")
  LOG_DIR="log/$NOW"
  mkdir -p "build/$LOG_DIR"
}

installPostgreSQL() {
  echo "Installing PostgreSQL..."
  POSTGRES_DIR="build/pgsql"
  if [ ! -f "$POSTGRES_DIR/bin/psql" ]; then
    echo "Downloading PostgreSQL..."
    if [ "$PLATFORM" = "Linux" ]; then
      local VERSION=
      if [ "$ARCH" = "x86_64" ]; then VERSION="x64-"; fi
      local DOWNLOAD_URL="http://get.enterprisedb.com/postgresql/postgresql-9.4.1-3-linux-${VERSION}binaries.tar.gz"
      curl -L -o "build/postgresql.tar.gz" "$DOWNLOAD_URL"
      echo "Unpacking PostgreSQL..."
      gunzip -c "build/postgresql.tar.gz" | tar xopf - -C "build/"
      rm "build/postgresql.tar.gz"
    elif [ "$PLATFORM" = "Mac" ]; then
      local DOWNLOAD_URL="http://get.enterprisedb.com/postgresql/postgresql-9.4.1-3-osx-binaries.zip"
      curl -L -o "build/postgresql.zip" "$DOWNLOAD_URL"
      echo "Unpacking PostgreSQL..."
      unzip -d "build/" "build/postgresql.zip" >/dev/null
      rm "build/postgresql.zip"
    else
      echo "ERROR: Invalid platform setting."
      exit 1
    fi
  fi

  "$POSTGRES_DIR/bin/initdb" -D "$POSTGRES_DIR/data"
  if ! "$POSTGRES_DIR/bin/pg_ctl" -D "$POSTGRES_DIR/data" start -l "build/$LOG_DIR/psql" -w -o "-p $DB_PORT" ; then
    echo "ERROR: Unable to start PostgreSQL database server."
    exit 1
  fi
}

createPostgreSQLDatabase() {
  "$POSTGRES_DIR/bin/createdb" -p "$DB_PORT" "$DB_NAME"  2>/dev/null
  "$POSTGRES_DIR/bin/createuser" -p "$DB_PORT" -s "$DB_USER" 2>/dev/null
  "$POSTGRES_DIR/bin/psql" -U "$DB_USER" -p "$DB_PORT" -d "$DB_NAME" -f "$SCRIPT_DIR/src/sql/postgresql.sql" 2>/dev/null
  writeDatabaseConfigFile "postgresql"
}

writeDatabaseConfigFile() {
  local DATABASE="$1"
  echo "$DATABASE" > "$APPD_DB_FILE"
  echo "$DB_PORT" >> "$APPD_DB_FILE"
  echo "$DB_NAME" >> "$APPD_DB_FILE"
  echo "$DB_USER" >> "$APPD_DB_FILE"
}

installTomcat() {
  echo "Setting up Tomcat..."
  echo "$JAVA_PORT" > "$APPD_TOMCAT_FILE"
  mkdir -p "build/tomcatrest/repo"
  mkdir -p "build/tomcatrest/bin"
  cp -rf "$SCRIPT_DIR/sampleapp/"* "build/tomcatrest" >/dev/null
  downloadTomcatDependency "org/glassfish/jersey/containers/jersey-container-servlet/2.10.1/jersey-container-servlet-2.10.1.jar"
  downloadTomcatDependency "org/glassfish/jersey/containers/jersey-container-servlet-core/2.10.1/jersey-container-servlet-core-2.10.1.jar"
  downloadTomcatDependency "org/glassfish/hk2/external/javax.inject/2.3.0-b05/javax.inject-2.3.0-b05.jar"
  downloadTomcatDependency "org/glassfish/jersey/core/jersey-common/2.10.1/jersey-common-2.10.1.jar"
  downloadTomcatDependency "javax/annotation/javax.annotation-api/1.2/javax.annotation-api-1.2.jar"
  downloadTomcatDependency "org/glassfish/jersey/bundles/repackaged/jersey-guava/2.10.1/jersey-guava-2.10.1.jar"
  downloadTomcatDependency "org/glassfish/hk2/hk2-api/2.3.0-b05/hk2-api-2.3.0-b05.jar"
  downloadTomcatDependency "org/glassfish/hk2/hk2-utils/2.3.0-b05/hk2-utils-2.3.0-b05.jar"
  downloadTomcatDependency "org/glassfish/hk2/external/aopalliance-repackaged/2.3.0-b05/aopalliance-repackaged-2.3.0-b05.jar"
  downloadTomcatDependency "org/glassfish/hk2/hk2-locator/2.3.0-b05/hk2-locator-2.3.0-b05.jar"
  downloadTomcatDependency "org/javassist/javassist/3.18.1-GA/javassist-3.18.1-GA.jar"
  downloadTomcatDependency "org/glassfish/hk2/osgi-resource-locator/1.0.1/osgi-resource-locator-1.0.1.jar"
  downloadTomcatDependency "org/glassfish/jersey/core/jersey-server/2.10.1/jersey-server-2.10.1.jar"
  downloadTomcatDependency "org/glassfish/jersey/core/jersey-client/2.10.1/jersey-client-2.10.1.jar"
  downloadTomcatDependency "javax/validation/validation-api/1.1.0.Final/validation-api-1.1.0.Final.jar"
  downloadTomcatDependency "javax/ws/rs/javax.ws.rs-api/2.0/javax.ws.rs-api-2.0.jar"
  downloadTomcatDependency "org/postgresql/postgresql/9.4-1200-jdbc41/postgresql-9.4-1200-jdbc41.jar"
  downloadTomcatDependency "com/github/dblock/waffle/waffle-jna/1.7/waffle-jna-1.7.jar"
  downloadTomcatDependency "net/java/dev/jna/jna/4.1.0/jna-4.1.0.jar"
  downloadTomcatDependency "net/java/dev/jna/jna-platform/4.1.0/jna-platform-4.1.0.jar"
  downloadTomcatDependency "org/slf4j/slf4j-api/1.7.7/slf4j-api-1.7.7.jar"
  downloadTomcatDependency "com/google/guava/guava/18.0/guava-18.0.jar"
  downloadTomcatDependency "org/slf4j/slf4j-simple/1.7.7/slf4j-simple-1.7.7.jar"
  downloadTomcatDependency "org/apache/tomcat/embed/tomcat-embed-core/7.0.57/tomcat-embed-core-7.0.57.jar"
  downloadTomcatDependency "org/apache/tomcat/embed/tomcat-embed-logging-juli/7.0.57/tomcat-embed-logging-juli-7.0.57.jar"
}

downloadTomcatDependency() {
  local TOMCAT_URL=$1
  if [ -f "build/tomcatrest/repo/$TOMCAT_URL" ]; then return 0; fi
  echo "Downloading http://repo.maven.apache.org/maven2/$TOMCAT_URL"
  curl -q --create-dirs -L -o "build/tomcatrest/repo/$TOMCAT_URL" "http://repo.maven.apache.org/maven2/$TOMCAT_URL"
}

startTomcat() {
  writeControllerInfo "build/AppServerAgent/conf/controller-info.xml" "JavaServer" "JavaServer01"
  for dir in "build/AppServerAgent/ver"* ; do
    writeControllerInfo "$dir/conf/controller-info.xml" "JavaServer" "JavaServer01"
  done
  export JAVA_OPTS="-javaagent:AppServerAgent/javaagent.jar"
  startProcess "Tomcat" "Tomcat Server (Port $JAVA_PORT)" "sh tomcatrest/bin/SampleAppServer.sh" "INFO: Starting ProtocolHandler [\"http-bio-$JAVA_PORT\"]" "SEVERE: Failed to initialize"
  cd "$SCRIPT_DIR"
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

installNode() {
  echo "Installing Node..."
  local URL_REF="linux"; local VERSION="x86"
  if [ "$PLATFORM" = "Mac" ]; then URL_REF="darwin"; fi
  if [ "$ARCH" = "x86_64" ]; then VERSION="x64"; fi

  NODE_DIR="node-v$NODE_VERSION-$URL_REF-$VERSION"

  if [ ! -f "build/$NODE_DIR/bin/node" ]; then
    promptUser "Node (v$NODE_VERSION) needs to be downloaded. Do you wish to continue?"
    local DOWNLOAD_URL="http://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$URL_REF-$VERSION.tar.gz"

    cd "build"
    curl -L -o "nodejs.tar.gz" "$DOWNLOAD_URL"
    gunzip -c "nodejs.tar.gz" | tar xopf -
    rm "nodejs.tar.gz"
    cd ".."
  fi

  installNodeModule "Express" "express" "4.12.3"
  installNodeModule "Request" "request" "2.55.0"
  installNodeModule "AppDynamics Agent" "appdynamics" "$NODE_AGENT_VERSION"
}

installNodeModule() {
  local DEPENDENCY_NAME="$1"; local DEPENDENCY_INSTALL="$2"; local DEPENDENCY_VERSION="$3"

  echo "Installing $DEPENDENCY_NAME for Node.js..."
  if [ ! -f "build/$NODE_DIR/lib/node_modules/$DEPENDENCY_INSTALL/package.json" ]; then
    "build/$NODE_DIR/bin/npm" install -g "$DEPENDENCY_INSTALL@$DEPENDENCY_VERSION"
  else echo "Already installed."; fi
}

startNode() {
  mkdir -p "build/node"
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
" "$CONTROLLER_ADDRESS" "$CONTROLLER_PORT" "$ACCOUNT_NAME" "$ACCOUNT_ACCESS_KEY" "$CONTROLLER_SSL" "$APPLICATION_NAME" > "build/node/server.js"
  echo "var nodePort = $NODE_PORT;" >> "build/node/server.js"
  echo "var javaPort = $JAVA_PORT;" >> "build/node/server.js"
  cat "$SCRIPT_DIR/src/server.js" >> "build/node/server.js"
  if [ ! -h "build/node/public" ]; then ln -s "$SCRIPT_DIR/src/public/" "build/node/public"; fi
  export NODE_PATH="$SCRIPT_DIR/build/$NODE_DIR/lib/node_modules"
  startProcess "node" "Node server (port $NODE_PORT)" "$NODE_DIR/bin/node node/server.js" "Node Server Started" "Error:"
}

installAgents() {
  installAgent "App Agent for Java" "AppServerAgent" "javaagent.jar" "appdynamics-java-agent.zip"
  installAgent "Database Agent" "DatabaseAgent" "db-agent.jar" "appdynamics-database-agent.zip"
  installAgent "Machine Agent" "MachineAgent" "machineagent.jar" "appdynamics-machine-agent.zip"
}

installAgent() {
  local AGENT_NAME=$1; local AGENT_DIR=$2; local AGENT_CHECK_FILE=$3; local AGENT_FILENAME=$4
  echo "Installing AppDynamics $AGENT_NAME... "
  if [ -f "build/$AGENT_DIR/$AGENT_CHECK_FILE" ]; then echo "Already installed."; return 0; fi
  mkdir -p "build/$AGENT_DIR"
  echo "Unpacking AppDynamics $AGENT_NAME (this may take a few minutes)..."
  unzip "$SCRIPT_DIR/agents/$AGENT_FILENAME" -d "build/$AGENT_DIR" >/dev/null
  echo "Finished unpacking AppDynamics $AGENT_NAME."
}

startMachineAgent() {
  writeControllerInfo "build/MachineAgent/conf/controller-info.xml"
  startProcess "machine-agent" "AppDynamics Machine Agent" "java -jar MachineAgent/machineagent.jar" "NOWAIT"
}

startDatabaseAgent() {
  writeControllerInfo "build/DatabaseAgent/conf/controller-info.xml"
  startProcess "database-agent" "AppDynamics Database Agent" "java -jar DatabaseAgent/db-agent.jar" "NOWAIT"
}

startProcess() {
  local LOG_KEY="$1"; PROCESS_NAME="$2"; local PROCESS_COMMAND="$3"
  local LOG_SUCCESS_TEXT="$4"; local LOG_FAILURE_TEXT="$5"; local NOWAIT=false
  APPD_ACTIVE_STARTUP_CHECK=
  echo "Starting $PROCESS_NAME..."
  cd "build"
  touch "$LOG_DIR/$LOG_KEY"
  if [ "$LOG_SUCCESS_TEXT" != "NOWAIT" ]; then
    tail -n 1 -f "$LOG_DIR/$LOG_KEY" | grep -m 1 "$(escaper "$LOG_SUCCESS_TEXT")\|$(escaper "$LOG_FAILURE_TEXT")" | { cat; echo >> "$LOG_DIR/$LOG_KEY"; } > "status-$LOG_KEY" &
    APPD_ACTIVE_STARTUP_CHECK=$!
  else NOWAIT=true; fi;
  ${PROCESS_COMMAND} >> "$LOG_DIR/$LOG_KEY" 2>&1  &
  cd ".."
  if [ "$NOWAIT" = false ]; then
    LOOPS=0
    while [ "$LOOPS" -ne "$TIMEOUT" -a -n "$(ps -p"$APPD_ACTIVE_STARTUP_CHECK" -o pid=)" ]; do
      printf "%s" "."
      LOOPS=$((LOOPS+1))
      sleep 1
    done
    echo ""
    if [ "$(head -n 1 "build/status-$LOG_KEY")" != "$LOG_SUCCESS_TEXT" -o "$LOOPS" -eq "$TIMEOUT" ]; then
      echo "ERROR: Unable to start $PROCESS_NAME."
      exit 1
    fi
    echo "$PROCESS_NAME started."
    rm "build/status-$LOG_KEY"
  fi
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

printSuccessMessage() {
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
}

waitForKill() {
  echo ""
  echo "Press Ctrl-C to quit the sample app server and clean up..."
  while true; do
    sleep 1
  done
}

onExitCleanup() {
  trap - TERM; stty echo
  echo ""
  if ${APP_STARTED} ; then
    echo "Killing all processes and cleaning up..."
    "build/pgsql/bin/pg_ctl" -D "build/pgsql/data" stop -m i 2>/dev/null
    rm -rf "build/cookies"
    rm -rf "build/status-"*
    rm -rf "$APPD_TOMCAT_FILE"
    rm -rf "$APPD_DB_FILE"
  fi
  kill 0
}

main "$@"
