#!/bin/bash

APPLICATION_NAME="TestApplication"
JAVA_PORT=8887
NODE_PORT=8888
MYSQL_PORT=8889
AXIS_VERSION="1.6.2"
ANT_VERSION="1.9.4"
NODE_VERSION="0.10.33"
MACHINE_AGENT_VERSION="4.0.1.0"
DATABASE_AGENT_VERSION="4.0.1.0"
APPSERVER_AGENT_VERSION="4.0.1.0"
SSL="false"
ACCOUNT_NAME=""
ACCOUNT_ACCESS_KEY=""
CONTROLLER_ADDRESS=false
CONTROLLER_PORT=false
NOPROMPT=false
PROMPT_EACH_REQUEST=false
TIMEOUT=300 #5 Minutes
ARCH=$(uname -m)
APP_STARTED=false
REQUIRED_SPACE=2500000

SCRIPT_PATH="$(readlink -f "$0" | xargs dirname)"
RUN_PATH="/var/tmp/AppDynamics"
mkdir -p "$RUN_PATH"; mkdir -p "$RUN_PATH/log"; cd "$RUN_PATH"
NOW=$(date +"%s")
RUN_LOG="$RUN_PATH/log/$NOW.log"
export NVM_DIR="$RUN_PATH/.nvm"
AXIS_DIR="axis2-$AXIS_VERSION"
export AXIS2_HOME="$RUN_PATH/$AXIS_DIR"
ANT_DIR="apache-ant-$ANT_VERSION"
export ANT_HOME="$RUN_PATH/$ANT_DIR"

export APPD_MYSQL_PORT_FILE="$RUN_PATH/mysql/mysql.port"
export APPD_TOMCAT_FILE="$RUN_PATH/tomcat"

about() {
  cat "$SCRIPT_PATH/about"
  echo "
  ** About $REQUIRED_SPACE kB of space is required in order to install the demo **

  * Note The following dependencies will are required and will also be installed:
    - wget
    - unzip
    - gzip
    - curl
    - libaio
  * The user appdmysql will be created for the mysql instance
  "
}

usage() {
  about
  printf "%s" "usage: sudo sh Appdemo.sh "
  cat "$SCRIPT_PATH/usage"
  exit 0
}

removeEnvironment() {
  echo "Removing Sample Application environment..."
  rm -rf "$RUN_PATH"
  usedel appdmysql >2/dev/null >/dev/null
  echo "Done"
  exit 0
}

if ! [ $(id -u) = 0 ]; then echo "Please run this script as root!"; usage; fi
while getopts :c:p:u:k:s:n:a:m:hdyz OPT; do
  case "$OPT" in
    c) CONTROLLER_ADDRESS=$OPTARG;;
    p) CONTROLLER_PORT=$OPTARG;;
    u) ACCOUNT_NAME=$OPTARG;;
    k) ACCOUNT_ACCESS_KEY=$OPTARG;;
    s) SSL=$OPTARG;;
    n) NODE_PORT=$OPTARG;;
    j) JAVA_PORT=$OPTARG;;
    m) MYSQL_PORT=$OPTARG;;
    h) usage;;
    y) NOPROMPT=true;;
    d) removeEnvironment;;
    z) PROMPT_EACH_REQUEST=true;;
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

if command -v yum 2>/dev/null >/dev/null ; then INSTALLER=yum; else INSTALLER=apt-get; fi

verifyUserAgreement() {
  if ${NOPROMPT} ; then return 0; fi
  echo "$1"
  local RESPONSE=
  while [ "$RESPONSE" != "Y" ]
  do
    read -p "Please input \"Y\" to accept, or \"n\" to decline and quit: " RESPONSE
    if [ "$RESPONSE" = "n" ]; then exit 1; fi
  done
}

spaceCheck() {
  local AVAILABLE_SPACE=$(df -P "$RUN_PATH" | awk 'NR==2 {print $4}')
  if [ ${AVAILABLE_SPACE} -lt ${REQUIRED_SPACE} ]; then
    echo "There is not enough space to install the demo!  At least $REQUIRED_SPACE is needed, there is only $AVAILABLE_SPACE"
    exit 1
  fi
}

startup() {
  about
  if ! ${PROMPT_EACH_REQUEST} ; then
    verifyUserAgreement "Do you agree to install all of the required dependencies if they do not exist and continue?
      (If you wish to be prompted before each operation run this script with the -z flag)"
    NOPROMPT=true
  fi

  spaceCheck
  APP_STARTED=true
}

escaper() {
  echo "$1" | sed 's/\([[$\/]\)/\\\1/g'
}

wait_for_pid () {
  local ACTION="$1"; local PID="$2"; local PID_PATH="$3"; local LOOPS=0; local RECHECK="1"
  avoid_race_condition="by checking again"

  while [ "$LOOPS" -ne "$TIMEOUT" ]; do
    case "$ACTION" in
      'created')
        if [ -s "$PID_PATH" ]; then LOOPS="" && break; fi;;
      'removed')
        if [ ! -s "$PID_PATH" ]; then LOOPS="" && break; fi;;
    esac

    if [ -n "$PID" ]; then
      if kill -0 "$PID" 2>/dev/null; then :
      else
        if [ -n "$RECHECK" ]; then RECHECK=""; continue; fi
        echo "The server quit without updating PID file ($PID_PATH)."
        return 1
      fi
    fi

    printf "%s" "."
    LOOPS=$((LOOPS+1))
    sleep 1
  done

  if [ -z "$LOOPS" ]; then return 0
  else return 1; fi
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
  " "$CONTROLLER_ADDRESS" "$CONTROLLER_PORT" "$SSL" "$ACCOUNT_NAME" "$ACCOUNT_ACCESS_KEY" "$APPLICATION_NAME" "$TIER_NAME" "$NODE_NAME" > "$WRITE_FILE"
}

startProcess() {
  local PROCESS_NAME="$1"; local PROCESS_COMMAND="$2"; local LOG_SUCCESS_TEXT="$3"; local LOG_FAILURE_TEXT="$4"; local NOWAIT=false;
  local STARTUP=
  echo "Starting $PROCESS_NAME..."
  if [ "$LOG_SUCCESS_TEXT" != "NOWAIT" ]; then
    tail -n 1 -f "$RUN_LOG" | grep -m 1 "$(escaper "$LOG_SUCCESS_TEXT")\|$(escaper "$LOG_FAILURE_TEXT")" | { cat; echo >> "$RUN_LOG"; } > "$RUN_PATH/status" &
    STARTUP=$!
  else NOWAIT=true; fi;
  ${PROCESS_COMMAND} >> "$RUN_LOG" 2>&1 &
  if [ "$NOWAIT" = false ]; then
    wait "$STARTUP"
    if [ "$(head -n 1 "$RUN_PATH/status")" != "$LOG_SUCCESS_TEXT" ]; then
      echo "Unable to start $PROCESS_NAME, exiting."
      exit 1
    fi
    echo "$PROCESS_NAME Started"
    rm "$RUN_PATH/status"
  fi
}

verifyDependency() {
  local INSTALL_FILE=
  if [ "$INSTALLER" = yum -a -n "$2" ]; then INSTALL_FILE="$2"
  else INSTALL_FILE="$1"; fi

  if [ -z "$INSTALL_FILE" ]; then return 1; fi

  echo "Verifying/Installing $INSTALL_FILE..."
  if ${NOPROMPT} ; then ${INSTALLER} -y install "$INSTALL_FILE"
  else ${INSTALLER} install "$INSTALL_FILE"; fi

  return 0
}

doDependencyInstalls() {
  verifyDependency "wget"
  verifyDependency "unzip"
  verifyDependency "gzip"
  verifyDependency "curl"
  verifyDependency "libaio1" "libaio"
  verifyDependency "" "'perl(Data::Dumper)'"
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
      wget -q -O/dev/null --save-cookies "$RUN_PATH/cookies" --post-data "username=$USERNAME&password=$PASSWORD" --no-check-certificate "https://login.appdynamics.com/sso/login/"
    done
    LOGGED_IN=true
  fi
  wget --load-cookies "$RUN_PATH/cookies" "$AGENT_URL" -O "$RUN_PATH/$AGENT_DIR/$AGENT_DIR.zip"
  echo "Unpacking $AGENT_DIR (this may take a few minutes)..."
  unzip "$RUN_PATH/$AGENT_DIR/$AGENT_DIR.zip" -d "$RUN_PATH/$AGENT_DIR" >/dev/null; rm "$RUN_PATH/$AGENT_DIR/$AGENT_DIR.zip"
  if [ ! -f "$RUN_PATH/$AGENT_DIR/$AGENT_CHECK_FILE" ]; then echo "Bad Agent Archive: $AGENT_DIR.zip, exiting."; exit 1; fi
}

doAgentInstalls() {
  agentInstall "MachineAgent" "machineagent.jar" "https://download.appdynamics.com/saas/public/archives/$MACHINE_AGENT_VERSION/MachineAgent-$MACHINE_AGENT_VERSION.zip"
  agentInstall "DatabaseAgent" "db-agent.jar" "https://download.appdynamics.com/saas/public/archives/$DATABASE_AGENT_VERSION/dbagent-$DATABASE_AGENT_VERSION.zip"
  agentInstall "AppServerAgent" "javaagent.jar" "https://download.appdynamics.com/saas/public/archives/$APPSERVER_AGENT_VERSION/AppServerAgent-$APPSERVER_AGENT_VERSION.zip"
}

doTomcatInstall() {
  echo "$JAVA_PORT" > "$APPD_TOMCAT_FILE"
  ln -sf "$SCRIPT_PATH/src/tomcat" "$RUN_PATH/tomcatrest"
}

startTomcat() {
  writeControllerInfo "$RUN_PATH/AppServerAgent/conf/controller-info.xml" "JavaServer" "JavaServer01"
  writeControllerInfo "$RUN_PATH/AppServerAgent/ver$APPSERVER_AGENT_VERSION/conf/controller-info.xml" "JavaServer" "JavaServer01"
  export JAVA_OPTS="-javaagent:$RUN_PATH/AppServerAgent/javaagent.jar"
  startProcess "Tomcat Server (Port $JAVA_PORT)" "sh $RUN_PATH/tomcatrest/bin/webapp" "INFO: Starting ProtocolHandler [\"http-bio-$JAVA_PORT\"]" "ERROR: Failed ProtocolHandler"
}

setupNodeNvm() {
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

doNodeInstall() {
  echo "Verifying/Installing Node..."
  setupNodeNvm
  if ! command -v nvm 2>/dev/null >/dev/null ; then
    verifyUserAgreement "Node needs to be downloaded, do you wish to continue?"
    wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.23.3/install.sh | NVM_DIR="$NVM_DIR" sh;
    echo "Inititalizing nvm automatically..."
    setupNodeNvm
  fi
  nvm install 0.10.33

  echo "Verifying/Installing AppDynamics NodeJS Agent..."
  if ! npm list appdynamics >/dev/null ; then npm install appdynamics@4.0.1; else echo "Installed"; fi

  echo "Verifying/Installing Node Express..."
  if ! npm list express >/dev/null ; then npm install express; else echo "Installed"; fi

  echo "Verifying/Installing Node Request..."
  if ! npm list request >/dev/null ; then npm install request; else echo "Installed"; fi

  echo "Verifying/Installing jQuery..."
  if ! npm list jquery >/dev/null ; then npm install jquery@2.1.3; else echo "Installed"; fi

  echo "Verifying/Installing Bootstrap..."
  if ! npm list bootstrap >/dev/null ; then npm install bootstrap@3.3.4; else echo "Installed"; fi

  echo "Verifying/Installing AngularJS..."
  if ! npm list angular >/dev/null ; then npm install angular@1.3.14; else echo "Installed"; fi

  echo "Verifying/Installing AngularRoute..."
  if ! npm list angular-route >/dev/null ; then npm install angular-route@1.3.14; else echo "Installed"; fi

}

doMySqlInstall() {
  echo "Verifying/Installing MySql..."
  if [ -f "$RUN_PATH/mysql/bin/mysqld" ]; then echo "Installed"; return 0; fi
  verifyUserAgreement "An instance of MySql needs to be downloaded, do you wish to continue?"
  local DLOAD_FILE="mysql-5.6.23-linux-glibc2.5-i686.tar.gz"
  if [ "$ARCH" = "x86_64" ]; then DLOAD_FILE="mysql-5.6.23-linux-glibc2.5-x86_64.tar.gz"; fi
  wget "http://dev.mysql.com/get/Downloads/MySQL-5.6/$DLOAD_FILE" -O "$RUN_PATH/mysql.tar.gz"
  echo "Unpacking MySql (this process may take a few minutes)..."
  gunzip -c "$RUN_PATH/mysql.tar.gz" | tar xopf -
  mv "$RUN_PATH/mysql-"* "$RUN_PATH/mysql"
  rm "$RUN_PATH/mysql.tar.gz"
}

doJavaInstall() {
  echo "Verifying/Installing Java..."
  if [ -f "$JAVA_HOME/bin/java" ]; then echo "Installed"; return 0; fi
  echo "Cannot find java in the JAVA_HOME environment variable, checking local install."
  if [ -f "$RUN_PATH/java/bin/java" ]; then echo "Installed"; export JAVA_HOME="$RUN_PATH/java"; return 0; fi
  verifyUserAgreement "Java is needed to continue.  Quit and make sure JAVA_HOME points to the correct location, or continue and the java JRE will be downloaded for you.
    You must accept the Oracle Binary Code License Agreement for Java SE (http://www.oracle.com/technetwork/java/javase/terms/license/index.html) to download the binaries.
    Do you accept the license agreement and wish to download the Java Binaries?"
  local DLOAD_FILE="jre-7u75-linux-i586.tar.gz"
  if [ "$ARCH" = "x86_64" ]; then DLOAD_FILE="jre-7u75-linux-x64.tar.gz"; fi
  wget --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u75-b13/$DLOAD_FILE" -O "$RUN_PATH/java.tar.gz"
  echo "Unpacking Java (this process may take a few minutes)..."
  gunzip -c "$RUN_PATH/java.tar.gz" | tar xopf -
  mv "$RUN_PATH/jdk"* "$RUN_PATH/java"
  rm "$RUN_PATH/java.tar.gz"
  export JAVA_HOME="$RUN_PATH/java"
}

setupMySql() {
  if [ -f "$RUN_PATH/mysql/data/ready" ]; then return 0; fi
  verifyUserAgreement "The script needs to create the user appdmysql to continue.
    The appdmysql user is created without a login.
    Is it ok to continue and create appdmysql:appdmysql?"
  groupadd appdmysql 2>/dev/null >/dev/null
  useradd -r -g appdmysql appdmysql 2>/dev/null >/dev/null
  chown -R appdmysql:appdmysql "$RUN_PATH/mysql"
  echo "Installing MySql DB..."
  "$RUN_PATH/mysql/scripts/mysql_install_db" --no-defaults --basedir="$RUN_PATH/mysql" --datadir="$RUN_PATH/mysql/data" --user=appdmysql --ldata="$RUN_PATH/mysql/data" >/dev/null
  chown -R appdmysql:appdmysql "$RUN_PATH/mysql"
  touch "$RUN_PATH/mysql/data/ready"
}

startMySql() {
  cd "$RUN_PATH/mysql"
  printf "%s" "Starting MySql"
  "$RUN_PATH/mysql/bin/mysqld_safe" --no-defaults --basedir="$RUN_PATH/mysql" --datadir="$RUN_PATH/mysql/data" --pid-file="$RUN_PATH/mysql/data/mysql.pid" --user=appdmysql --socket="$RUN_PATH/mysql/data/mysql.sock" --port="$MYSQL_PORT" --log-error="$RUN_PATH/mysql/mysql.err" >/dev/null 2>&1 &
  if ! wait_for_pid created "$!" "$RUN_PATH/mysql/data/mysql.pid" ; then echo " FAILED!"; exit 1; fi
  echo " SUCCESS!"
  cd "$RUN_PATH"
  echo "$MYSQL_PORT" > "$APPD_MYSQL_PORT_FILE"
}

stopMySql() {
  if [ -s "$RUN_PATH/mysql/data/mysql.pid" ]; then
    local MYSQL_PID=$(cat "$RUN_PATH/mysql/data/mysql.pid")

    if (kill -0 "$MYSQL_PID" 2>/dev/null); then
      printf "%s" "Shutting down MySQL"
      kill "$MYSQL_PID"
      wait_for_pid removed "$MYSQL_PID" "$RUN_PATH/mysql/data/mysql.pid"
      echo " DONE"
    else
      echo "MySQL server process #$MYSQL_PID is not running!"
      rm "$RUN_PATH/mysql/data/mysql.pid"
    fi
  else
    echo "MySQL server PID file could not be found!"
  fi
  echo ""
}

runMySqlScripts() {
  "$RUN_PATH/mysql/bin/mysql" --socket="$RUN_PATH/mysql/data/mysql.sock" < "$SCRIPT_PATH/src/mysql.sql"
}

startMachineAgent() {
  writeControllerInfo "$RUN_PATH/MachineAgent/conf/controller-info.xml"
  startProcess "Machine Agent" "java -jar $RUN_PATH/MachineAgent/machineagent.jar" "NOWAIT"
}

startDatabaseAgent() {
  writeControllerInfo "$RUN_PATH/DatabaseAgent/conf/controller-info.xml"
  startProcess "Database Agent" "$JAVA_HOME/bin/java -Dappdynamics.controller.hostName=$CONTROLLER_ADDRESS -Dappdynamics.controller.port=$CONTROLLER_PORT -Dappdynamics.controller.ssl.enabled=$SSL -Dappdynamics.agent.accountName=$ACCOUNT_NAME -Dappdynamics.agent.accountAccessKey=$ACCOUNT_ACCESS_KEY -jar $RUN_PATH/DatabaseAgent/db-agent.jar" "NOWAIT"
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
  " "$CONTROLLER_ADDRESS" "$CONTROLLER_PORT" "$ACCOUNT_NAME" "$ACCOUNT_ACCESS_KEY" "$SSL" "$APPLICATION_NAME" > "$RUN_PATH/node/server.js"
  cat "$SCRIPT_PATH/src/server.js" >> "$RUN_PATH/node/server.js"
  ln -sf "$RUN_PATH/node_modules/angular/" "$SCRIPT_PATH/src/public/angular"
  ln -sf "$RUN_PATH/node_modules/angular-route/" "$SCRIPT_PATH/src/public/angular-route"
  ln -sf "$RUN_PATH/node_modules/bootstrap/dist/" "$SCRIPT_PATH/src/public/bootstrap"
  ln -sf "$RUN_PATH/node_modules/jquery/dist/" "$SCRIPT_PATH/src/public/jquery"
  if [ ! -h "$RUN_PATH/node/public" ]; then ln -s "$SCRIPT_PATH/src/public/" "$RUN_PATH/node/public"; fi
  startProcess "Node (Port $NODE_PORT)" "node $RUN_PATH/node/server.js" "Node Server Started" "Node Server Failed"
}

onExitCleanup() {
  trap - TERM; stty echo
  echo ""
  if ${APP_STARTED} ; then
    echo "Killing all processes and cleaning up..."
    rm -f "$RUN_PATH/cookies"
    rm -f "$RUN_PATH/status"
    rm -f "$RUN_PATH/tomcat"
    stopMySql
  fi
  kill 0
}
trap "exit" INT TERM && trap onExitCleanup EXIT

startup
doDependencyInstalls
doJavaInstall
doTomcatInstall
doMySqlInstall
doNodeInstall
doAgentInstalls
setupMySql
startMySql
runMySqlScripts
startMachineAgent
startDatabaseAgent
startTomcat
startNode

echo "Sample App Environment Setup Complete!"
echo "Visit http://localhost:$NODE_PORT to view the sample app, or"
while :
do
  read -p "Specify the number of times to hit the server (or Press [CTRL+C] to stop...): " LOAD_HITS
  for LOOPS in $(seq 1 "$LOAD_HITS")
  do
    echo "Performing Load Hit $LOOPS of $LOAD_HITS"
    curl "http://localhost:$NODE_PORT" 2>/dev/null >/dev/null
    sleep 1
  done
  echo
done
