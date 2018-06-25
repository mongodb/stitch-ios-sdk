set -e

cc=`find ./.build/checkouts/ -type d -name "CommonCrypto*" -print`

xcodeproj=`find . -type d -name "$1.xcodeproj" -print`
scheme=$2
do_not_test=$3
sim_uuid=$4
echo "...testing $1"

xcodebuild \
    -project "`pwd`/$xcodeproj" \
    -destination "id=$sim_uuid" \
    -derivedDataPath "localDerivedData" \
    -scheme $scheme \
    -json \
    OTHER_LDFLAGS="-rpath `pwd`/vendor/MobileSDKs/iphoneos/lib -fprofile-arcs -ftest-coverage" \
    LIBRARY_SEARCH_PATHS="`pwd`/vendor/MobileSDKs/iphoneos/lib" \
    SWIFT_INCLUDE_PATHS="`pwd`/$cc `pwd`/vendor/MobileSDKs/include `pwd`/vendor/MobileSDKs/include/libbson-1.0 `pwd`/vendor/MobileSDKs/include/libmongoc-1.0 `pwd`/vendor/MobileSDKs/include/mongo/embedded-v1/" \
    FRAMEWORK_INCLUDE_PATHS="`pwd`/localDerivedData " \
    ENABLE_BITCODE=NO \
    IPHONEOS_DEPLOYMENT_TARGET="10.2" \
    GCC_PREPROCESSOR_DEFINITIONS="${*:5}" \
    `[[ $do_not_test != YES ]] && echo "-enableCodeCoverage YES" || echo ""` \
    `[[ $do_not_test != YES ]] && echo "test" || echo ""`

echo "$status"
if [[ $do_not_test != YES ]]; then
    mkdir -p CoverageData
    find . -type f -name Coverage.profdata -exec cp {} ./$scheme.tmp.profdata \;
    find . -type f -name $1 -exec cp {} ./$1.tmp \;
    xcrun llvm-cov show -instr-profile=$scheme.tmp.profdata $1.tmp > CoverageData/$1.cov
    rm -rf $scheme.tmp.profdata
    rm -rf $1.tmp
fi
