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

sanitize_imports() (
    log_i "sanitizing $1"

    local local_module_path=`[[ ! -z $FILE_PATH ]] && echo "$FILE_PATH" || echo "$1"`
    find $local_module_path -type f -name '*.swift' | while read i; do
        sed -i '' "/import MongoSwift/d" $i
        for ((j=0; j < "${#MODULES[@]}"; j++)) ; do
            module=${MODULES[$j]}

            module_name="${module%%:*}"
            sed -i '' "/import $module_name/d" $i
        done
    done
)

copy_module() {
    local module_name=$1
    local module_path=`[[ ! -z $FILE_PATH ]] && echo "$FILE_PATH" || echo "$2"`

    mkdir -p dist/$module_name
    cp -r $module_path/* dist/$module_name
}

mkdir -p dist

for ((i=0; i < "${#MODULES[@]}"; i++)) ; do        
    module=${MODULES[$i]}

    module_name="${module%%:*}"
    module_path="${module#*:}"

    if [[ ! -z $1 ]]; then
        if [[ $module_name == $1 ]]; then
            FILE_PATH=$2
            copy_module $module_name $module_path
            sanitize_imports $module_name
        fi
    else
        copy_module $module_name $module_path
        sanitize_imports $module_name
    fi
done

