set -e

cc=`find ./.build/checkouts/ -type d -name "CommonCrypto*" -print`

xcodeproj=`find . -type d -name "$1.xcodeproj" -print`
scheme=$2
do_not_test=$3
sim_uuid=$4
echo "...testing $1"

# security create-keychain -p admin MyKeychain.keychain
# security import MyPrivateKey.p12 -t agg -k MyKeychain.keychain -P admin -A

# security list-keychains -s "MyKeyhain.keychain"
# security default-keychain -s "MyKeychain.keychain"
# security unlock-keychain -p "admin" "MyKeychain.keychain"

codesign --force --sign - --verbose Frameworks/ios/MongoSwift.framework/MongoSwift
xcodebuild \
    -project "`pwd`/$xcodeproj" \
    -destination "id=$sim_uuid" \
    -derivedDataPath "localDerivedData" \
    -scheme $scheme \
    -verbose \
    FRAMEWORK_SEARCH_PATHS="`pwd`/Frameworks/ios `pwd`/localDerivedData" \
    OTHER_LDFLAGS="-rpath `pwd`/Frameworks/ios" \
    ENABLE_BITCODE=NO \
    IPHONEOS_DEPLOYMENT_TARGET="10.2" \
    GCC_PREPROCESSOR_DEFINITIONS="${*:5}" \
    RUN_CLANG_STATIC_ANALYZER=NO \
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
