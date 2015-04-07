#!/bin/sh
# ----------------------------------------------------------------------------
#  Copyright 2001-2006 The Apache Software Foundation.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# ----------------------------------------------------------------------------

#   Copyright (c) 2001-2002 The Apache Software Foundation.  All rights
#   reserved.

BASEDIR=`dirname $0`/..
BASEDIR=`(cd "$BASEDIR"; pwd)`



# OS specific support.  $var _must_ be set to either true or false.
cygwin=false;
darwin=false;
case "`uname`" in
  CYGWIN*) cygwin=true ;;
  Darwin*) darwin=true
           if [ -z "$JAVA_VERSION" ] ; then
             JAVA_VERSION="CurrentJDK"
           else
             echo "Using Java version: $JAVA_VERSION"
           fi
           if [ -z "$JAVA_HOME" ] ; then
             JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Versions/${JAVA_VERSION}/Home
           fi
           ;;
esac

if [ -z "$JAVA_HOME" ] ; then
  if [ -r /etc/gentoo-release ] ; then
    JAVA_HOME=`java-config --jre-home`
  fi
fi

# For Cygwin, ensure paths are in UNIX format before anything is touched
if $cygwin ; then
  [ -n "$JAVA_HOME" ] && JAVA_HOME=`cygpath --unix "$JAVA_HOME"`
  [ -n "$CLASSPATH" ] && CLASSPATH=`cygpath --path --unix "$CLASSPATH"`
fi

# If a specific java binary isn't specified search for the standard 'java' binary
if [ -z "$JAVACMD" ] ; then
  if [ -n "$JAVA_HOME"  ] ; then
    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
      # IBM's JDK on AIX uses strange locations for the executables
      JAVACMD="$JAVA_HOME/jre/sh/java"
    else
      JAVACMD="$JAVA_HOME/bin/java"
    fi
  else
    JAVACMD=`which java`
  fi
fi

if [ ! -x "$JAVACMD" ] ; then
  echo "Error: JAVA_HOME is not defined correctly."
  echo "  We cannot execute $JAVACMD"
  exit 1
fi

if [ -z "$REPO" ]
then
  REPO="$BASEDIR"/repo
fi

CLASSPATH=$CLASSPATH_PREFIX:"$BASEDIR"/etc:"$REPO"/org/glassfish/jersey/containers/jersey-container-servlet/2.10.1/jersey-container-servlet-2.10.1.jar:"$REPO"/org/glassfish/jersey/containers/jersey-container-servlet-core/2.10.1/jersey-container-servlet-core-2.10.1.jar:"$REPO"/org/glassfish/hk2/external/javax.inject/2.3.0-b05/javax.inject-2.3.0-b05.jar:"$REPO"/org/glassfish/jersey/core/jersey-common/2.10.1/jersey-common-2.10.1.jar:"$REPO"/javax/annotation/javax.annotation-api/1.2/javax.annotation-api-1.2.jar:"$REPO"/org/glassfish/jersey/bundles/repackaged/jersey-guava/2.10.1/jersey-guava-2.10.1.jar:"$REPO"/org/glassfish/hk2/hk2-api/2.3.0-b05/hk2-api-2.3.0-b05.jar:"$REPO"/org/glassfish/hk2/hk2-utils/2.3.0-b05/hk2-utils-2.3.0-b05.jar:"$REPO"/org/glassfish/hk2/external/aopalliance-repackaged/2.3.0-b05/aopalliance-repackaged-2.3.0-b05.jar:"$REPO"/org/glassfish/hk2/hk2-locator/2.3.0-b05/hk2-locator-2.3.0-b05.jar:"$REPO"/org/javassist/javassist/3.18.1-GA/javassist-3.18.1-GA.jar:"$REPO"/org/glassfish/hk2/osgi-resource-locator/1.0.1/osgi-resource-locator-1.0.1.jar:"$REPO"/org/glassfish/jersey/core/jersey-server/2.10.1/jersey-server-2.10.1.jar:"$REPO"/org/glassfish/jersey/core/jersey-client/2.10.1/jersey-client-2.10.1.jar:"$REPO"/javax/validation/validation-api/1.1.0.Final/validation-api-1.1.0.Final.jar:"$REPO"/javax/ws/rs/javax.ws.rs-api/2.0/javax.ws.rs-api-2.0.jar:"$REPO"/mysql/mysql-connector-java/5.1.6/mysql-connector-java-5.1.6.jar:"$REPO"/org/apache/tomcat/embed/tomcat-embed-core/7.0.57/tomcat-embed-core-7.0.57.jar:"$REPO"/org/apache/tomcat/embed/tomcat-embed-logging-juli/7.0.57/tomcat-embed-logging-juli-7.0.57.jar:"$REPO"/org/apache/tomcat/embed/tomcat-embed-jasper/7.0.57/tomcat-embed-jasper-7.0.57.jar:"$REPO"/org/apache/tomcat/embed/tomcat-embed-el/7.0.57/tomcat-embed-el-7.0.57.jar:"$REPO"/org/eclipse/jdt/core/compiler/ecj/4.4/ecj-4.4.jar:"$REPO"/storefront.jar
EXTRA_JVM_ARGUMENTS=""

# For Cygwin, switch paths to Windows format before running java
if $cygwin; then
  [ -n "$CLASSPATH" ] && CLASSPATH=`cygpath --path --windows "$CLASSPATH"`
  [ -n "$JAVA_HOME" ] && JAVA_HOME=`cygpath --path --windows "$JAVA_HOME"`
  [ -n "$HOME" ] && HOME=`cygpath --path --windows "$HOME"`
  [ -n "$BASEDIR" ] && BASEDIR=`cygpath --path --windows "$BASEDIR"`
  [ -n "$REPO" ] && REPO=`cygpath --path --windows "$REPO"`
fi

exec "$JAVACMD" $JAVA_OPTS \
  $EXTRA_JVM_ARGUMENTS \
  -classpath "$CLASSPATH" \
  -Dapp.name="webapp" \
  -Dapp.pid="$$" \
  -Dapp.repo="$REPO" \
  -Dbasedir="$BASEDIR" \
  com.appdynamics.demo.StoreFrontJersey \
  "$@"
