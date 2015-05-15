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
mv "sampleapp/repo/com/appdynamics" "sampleapp-appdynamics"
rm -rf "sampleapp/repo"
mkdir "sampleapp/repo"
mkdir "sampleapp/repo/com"
mv "sampleapp-appdynamics" "sampleapp/repo/com/appdynamics"

find "src/public" -type l | xargs rm -rf

# Make sure windows line endings are correct before packaging
unix2dos "INSTALL_Windows.bat"
unix2dos "vbs/download.vbs"
unix2dos "vbs/unzip.vbs"

# Create Zip file
rm -rf "appdynamics-sample-app.zip"
zip "appdynamics-sample-app.zip" -r "INSTALL_Linux.sh" "INSTALL_Mac.sh" "INSTALL_Windows.bat" README usage sampleapp src vbs
