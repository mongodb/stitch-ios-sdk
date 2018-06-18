#!/bin/bash

MODULES=(
    "StitchCoreSDK:Core/StitchCoreSDK/Sources/StitchCoreSDK"
    "StitchCoreAWSS3Service:Core/Services/StitchCoreAWSS3Service/Sources/StitchCoreAWSS3Service"
    "StitchCoreAWSSESService:Core/Services/StitchCoreAWSSESService/Sources/StitchCoreAWSSESService"
    "StitchCoreFCMService:Core/Services/StitchCoreFCMService/Sources/StitchCoreFCMService"
    "StitchCoreHTTPService:Core/Services/StitchCoreHTTPService/Sources/StitchCoreHTTPService"
    "StitchCoreTwilioService:Core/Services/StitchCoreTwilioService/Sources/StitchCoreTwilioService"
    "StitchCoreRemoteMongoDBService:Core/Services/StitchCoreRemoteMongoDBService/Sources/StitchCoreRemoteMongoDBService"
    "StitchCoreLocalMongoDBService:Core/Services/StitchCoreLocalMongoDBService/Sources/StitchCoreLocalMongoDBService"

    "StitchCore:iOS/StitchCore/StitchCore"
    "StitchAWSS3Service:iOS/Services/StitchAWSS3Service/StitchAWSS3Service"
    "StitchAWSSESService:iOS/Services/StitchAWSSESService/StitchAWSSESService"
    "StitchFCMService:iOS/Services/StitchFCMService/StitchFCMService"
    "StitchHTTPService:iOS/Services/StitchHTTPService/StitchHTTPService"
    "StitchRemoteMongoDBService:iOS/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService"
    "StitchTwilioService:iOS/Services/StitchTwilioService/StitchTwilioService"
    "StitchLocalMongoDBService:iOS/Services/StitchLocalMongoDBService/StitchLocalMongoDBService"
)

log_i() {
    printf "\033[1;36m$1\033[0m\n"
}

log_w() {
    printf "\033[1;33m$1\033[0m\n"
}

log_e() {
    printf "\033[1;31m$1\033[0m\n"
}

sanitize_imports() (
    local module=$1
    local sources=$2

    log_i "sanitizing $module"

    find $sources -type f -name '*.swift' | while read i; do
        sanitized_path="${i#*$sources/}"
        sed -i '' "/import MongoSwift/d" dist/$module/$sanitized_path
    done
)

copy_module() {
    local module_name=$1
    local module_path=$2

    mkdir -p dist/$module_name

    cp -r $module_path/* dist/$module_name
}

mkdir -p dist

while [[ $# -gt 0 ]]
do
i="$1"
case $i in
    -m=*|--module=*)
    MODULE="${i#*=}"
    shift # past argument=value
    ;;
    -s|--sources=*)
    SOURCES="${i#*=}"
    shift # past argument=value
    ;;
    -h|--help)
    log_w "[-m|--module]=MODULE_NAME [-s|--sources]=RELATIVE_SOURCE_PATH"
    exit 0
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done

if [[ -z $MODULE ]]; then 
    log_e "must have module"
    exit 1
fi

[[ -z $SOURCES ]] && log_w "no source path provided; using defaults"

for ((i=0; i < "${#MODULES[@]}"; i++)) ; do
    module=${MODULES[$i]}

    module_name="${module%%:*}"
    module_path="${module#*:}"
    if [[ $module_name == $MODULE ]]; then
        resolved_path=`[[ -z $SOURCES || ! -d $SOURCES ]] && echo $module_path || echo $SOURCES`
        copy_module $module_name $resolved_path
        sanitize_imports $module_name $resolved_path
        break
    fi
done
