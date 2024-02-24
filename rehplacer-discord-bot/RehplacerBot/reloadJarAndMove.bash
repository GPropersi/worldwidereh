#!/usr/bin/env bash

JAR_FILE_NAME_ORIGINAL="RehplacerBot-1.0-SNAPSHOT.jar";
JAR_FILE_NAME_FINAL="RehplacerBot.jar";

pushd . &> /dev/null;
cd "$(dirname "$0")";
SCRIPT_DIR="$(pwd)" &> /dev/null;

cd $SCRIPT_DIR;

./gradlew clean build;

./gradlew bootJar;

mv build/libs/$JAR_FILE_NAME_ORIGINAL $JAR_FILE_NAME_FINAL;

echo "Created jar and moved it over";

popd &> /dev/null;

