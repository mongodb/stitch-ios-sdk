all: git clean update project build
git:
	-git init
	git config user.email "evg@mongodb.com"
	git config user.name "evg"
	git add -A
	git commit -m "init"
lint:
	swiftlint
clean:
	swift package clean
build:
	swift build -Xcc -I../MobileSDKs/include/libbson-1.0/ -Xcc -I../MobileSDKs/include/libmongoc-1.0
update:
	swift package update
test:
	# temporary until a fix is in for .brew dependency for libmongoc
	xcodebuild test -workspace ../Stitch.xcworkspace/ -scheme StitchCoreAdminClient-Package -configuration Debug -destination "platform=iOS Simulator,name=iPhone 7,OS=11.2"
project:
	swift package generate-xcodeproj --xcconfig-overrides StitchCoreAdminClient.xcconfig