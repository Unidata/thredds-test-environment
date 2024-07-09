#!/bin/bash -l
#
# Usage entrypoint.sh vendor java-version build-tool test-command
#
# Example (gradle wrapper):
#
#   ./entrypoint.sh "temurin" "11" "gradlew" "clean testAll"
#
# Example (maven):
#
#   ./entrypoint.sh "zulu" "8" "mvn" "clean test"

JAVA_VENDOR=${1}
JAVA_VERSION=${2}
BUILD_TOOL=${3}
TEST_COMMAND=${4}

VALID_JAVA_VENDORS=("temurin" "zulu")
VALID_JAVA_VERSIONS=("8" "11" "16" "17")
VALID_BUILD_TOOLS=("gradlew" "mvn")

#
# args: INPUT_NAME
#
# example:
# validate "VENDOR"
#
validate () {
    INPUT_NAME=${1}
    VALUE_TO_VALIDATE="${!INPUT_NAME}"
    VALID_VALUES_ARRAY_NAME="VALID_${INPUT_NAME}S"
    VALID_VALUES_ARRAY_NAME=${VALID_VALUES_ARRAY_NAME}[@]
    VALID_VALUES_ARRAY=("${!VALID_VALUES_ARRAY_NAME}")
    if [[ ! " ${VALID_VALUES_ARRAY[@]} " =~ " ${VALUE_TO_VALIDATE} " ]]; then
        VALID=$(printf " || %s" "${VALID_VALUES_ARRAY[@]}")
        VALID=${VALID:4}
        echo "Invalid value \"${VALUE_TO_VALIDATE}\". ${INPUT_NAME} must be one of [ ${VALID} ]"
        exit 1
    fi
} 
 
validate "JAVA_VENDOR"
validate "JAVA_VERSION"
validate "BUILD_TOOL"

if [ ${BUILD_TOOL} == "gradlew" ]
then
    BUILD_TOOL="./${BUILD_TOOL}"
fi

COMMAND="${BUILD_TOOL} ${BUILD_COMMAND} ${TEST_COMMAND}"
echo ${COMMAND}

select-java ${JAVA_VENDOR} ${JAVA_VERSION}
eval ${COMMAND}
