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

#Run paven package to build java server jar
cd "$SCRIPT_PATH/maven"
mvn package
cd "$SCRIPT_PATH"

#We do not need to package java dependencies as they will be downloaded by the install script
rm -rf "$SCRIPT_PATH/sampleapp/repo/javax"
rm -rf "$SCRIPT_PATH/sampleapp/repo/mysql"
rm -rf "$SCRIPT_PATH/sampleapp/repo/org"

find "$SCRIPT_PATH/src/public" -type l | xargs rm

#Create distributable package
rm -rf "$SCRIPT_PATH/sampleapp.tar.gz"
rm -rf "$SCRIPT_PATH/sampleapp.zip"
tar -cvzf "$SCRIPT_PATH/sampleapp.tar.gz" --exclude "INSTALL_Windows.bat" --exclude "vbs" --exclude "package.sh" --exclude "maven" --exclude ".idea" --exclude ".gitignore" --exclude ".git" --exclude "sampleapp.tar.gz" --exclude "sampleapp.zip" *
zip "$SCRIPT_PATH/sampleapp.zip" . -r -x "INSTALL_Linux.sh" "package.sh" "maven/*" ".idea/*" ".gitignore" ".git/*" "sampleapp.tar.gz" "sampleapp.zip"