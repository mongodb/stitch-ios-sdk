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

SANITIZE_ALL=NO

log_i() {
    printf "\033[1;36m$1\033[0m\n"
}

log_w() {
    printf "\033[1;33m$1\033[0m\n"
}

sanitize_imports() (
    log_i "sanitizing $1"

    local local_module_path=`[[ ! -z $SOURCES ]] && echo "$SOURCES" || echo "$2"`
    local sources=`[[ ! -z $SOURCES ]] && echo "$SOURCES" || echo "$2"`
    find $local_module_path -type f -name '*.swift' | while read i; do
        sanitized_path="${i#*$sources/}"
        sed -i '' "/import MongoSwift/d" dist/$1/$sanitized_path
        if [[ $SANITIZE_ALL == YES ]]; then
            for ((j=0; j < "${#MODULES[@]}"; j++)) ; do
                module=${MODULES[$j]}

                module_name="${module%%:*}"
                sed -i '' "/import $module_name/d" dist/$1/$sanitized_path
            done
        fi
    done
)

copy_module() {
    local module_name=$1
    local module_path=`[[ ! -z $SOURCES ]] && echo "$SOURCES" || echo "$2"`

    mkdir -p dist/$module_name
    cp -r $module_path/* dist/$module_name
}

mkdir -p dist

for i in "$@"
do
case $i in
    -m=*|--module=*)
    MODULE="${i#*=}"
    shift # past argument=value
    ;;
    -sA|--sanitize_all)
    SANITIZE_ALL=YES
    shift # past argument=value
    ;;
    -s|--sources=*)
    SOURCES="${i#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

for ((i=0; i < "${#MODULES[@]}"; i++)) ; do        
    module=${MODULES[$i]}

    module_name="${module%%:*}"
    module_path="${module#*:}"
    if [[ ! -z $MODULE ]]; then
        if [[ $module_name == $MODULE ]]; then
            log_w "found module $MODULE"
            copy_module $module_name $module_path
            sanitize_imports $module_name $module_path
        fi
    else
        log_w "sanitizing all modules"
        copy_module $module_name $module_path
        sanitize_imports $module_name $module_path
    fi
done

