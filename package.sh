#!/bin/bash

if [ $(id -u) = 0 ]; then
  echo "Do not run this packager as root!"
  exit 1
fi

SCRIPT_PATH="$(readlink -f "$0" | xargs dirname)"

if ! which mvn >/dev/null ; then
  echo "Apache Maven is required to perform packaging, please make sure your PATH environment variable points to its location, exiting."
  exit 1
fi

# Run maven package to build java server jar
cd "$SCRIPT_PATH/maven"
mvn package
cd "$SCRIPT_PATH"

# We do not need to package java dependencies as they will be downloaded by the install script
rm -rf "$SCRIPT_PATH/sampleapp/repo/javax"
rm -rf "$SCRIPT_PATH/sampleapp/repo/mysql"
rm -rf "$SCRIPT_PATH/sampleapp/repo/org"

find "$SCRIPT_PATH/src/public" -type l | xargs rm -rf

# Make sure windows line endings are correct before packaging
unix2dos "$SCRIPT_PATH/INSTALL_Windows.bat"
unix2dos "$SCRIPT_PATH/vbs/download.vbs"
unix2dos "$SCRIPT_PATH/vbs/unzip.vbs"

# Create Zip file
rm -rf "$SCRIPT_PATH/appdynamics-sample-app.zip"
zip "$SCRIPT_PATH/appdynamics-sample-app.zip" -r "INSTALL_Linux.sh" "INSTALL_Mac.bat" "INSTALL_Windows.bat" about usage sampleapp src vbs
