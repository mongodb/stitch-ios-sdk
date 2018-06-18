#!/bin/bash

MODULES=(
    "StitchCoreSDK:Core/StitchCoreSDK/Sources/StitchCoreSDK"
    "StitchCoreAWSS3Service:Core/Services/StitchCoreAWSS3Service/Sources/StitchCoreAWSS3Service"
    "StitchCoreHTTPService:Core/Services/StitchCoreHTTPService/Sources/StitchCoreHTTPService"
    "StitchCore:iOS/StitchCore/StitchCore"
    "StitchAWSS3Service:iOS/Services/StitchAWSS3Service/StitchAWSS3Service"
    "StitchAWSSESService:iOS/Services/StitchAWSSESService/StitchAWSSESService"
    "StitchHTTPService:iOS/Services/StitchHTTPService/StitchHTTPService"
)

log_i() {
    printf "\033[1;35m$1\033[0m\n"
}

sanitize_imports() (
    log_i "sanitizing $1"

    find "$1" -type f -name '*.swift' | while read i; do
        sed -i '' "/import MongoSwift/d" $i
        for ((j=0; j < "${#MODULES[@]}"; j++)) ; do
            module=${MODULES[$j]}

            module_name="${module%%:*}"
            sed -i '' "/import $module_name/d" $i
        done
    done
)

mkdir -p SDK

for ((i=0; i < "${#MODULES[@]}"; i++)) ; do
    module=${MODULES[$i]}

    module_name="${module%%:*}"
    module_path="${module#*:}"

    mkdir -p SDK/$module_name
    cp -r $module_path/* SDK/$module_name
    sanitize_imports SDK/$module_name
done
