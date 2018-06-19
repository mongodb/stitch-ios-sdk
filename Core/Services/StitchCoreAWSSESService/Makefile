all: git project
git:
	git init
	git add .
	git commit --allow-empty -m "init"
lint:
	swiftlint
clean:
	swift package clean
build:
	swift build -Xcc -I../../../vendor/MobileSDKs/include/libbson-1.0/ -Xcc -I../../../vendor/MobileSDKs/include/libmongoc-1.0
update:
	swift package update
test:
	# temporary until a fix is in for .brew dependency for libmongoc
	xcodebuild test -workspace ../../../Stitch.xcworkspace/ -scheme StitchCoreAWSSESService-Package -configuration Debug -destination "platform=iOS Simulator,name=iPhone 7,OS=11.2"
project:
	swift package --build-path ../../../.build generate-xcodeproj --xcconfig-overrides StitchCoreAWSSESService.xcconfig
