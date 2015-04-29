#!/bin/bash

if [ $(id -u) = 0 ]; then
  echo "Do not run this packager as root!"
  exit 1
fi

pushd `dirname $0` > /dev/null
SCRIPT_DIR=`pwd -P`
popd > /dev/null

if ! which mvn >/dev/null ; then
  echo "Apache Maven is required to perform packaging but is not found in your PATH. Exiting."
  exit 1
fi

# Run maven package to build java server jar
cd "$SCRIPT_DIR/maven"
mvn clean
mvn package
cd "$SCRIPT_DIR"

# We do not need to package java dependencies as they will be downloaded by the install script
mv "$SCRIPT_DIR/sampleapp/repo/com/appdynamics" "$SCRIPT_DIR/sampleapp-appdynamics"
rm -rf "$SCRIPT_DIR/sampleapp/repo"
mkdir "$SCRIPT_DIR/sampleapp/repo"
mkdir "$SCRIPT_DIR/sampleapp/repo/com"
mv "$SCRIPT_DIR/sampleapp-appdynamics" "$SCRIPT_DIR/sampleapp/repo/com/appdynamics"

find "$SCRIPT_DIR/src/public" -type l | xargs rm -rf

# Make sure windows line endings are correct before packaging
unix2dos "$SCRIPT_DIR/INSTALL_Windows.bat"
unix2dos "$SCRIPT_DIR/vbs/download.vbs"
unix2dos "$SCRIPT_DIR/vbs/unzip.vbs"

# Create Zip file
rm -rf "$SCRIPT_DIR/appdynamics-sample-app.zip"
zip "$SCRIPT_DIR/appdynamics-sample-app.zip" -r "INSTALL_Linux.sh" "INSTALL_Mac.sh" "INSTALL_Windows.bat" README usage sampleapp src vbs
