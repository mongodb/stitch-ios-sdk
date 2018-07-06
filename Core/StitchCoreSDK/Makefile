all: prepare build
git:
	git init
	git add .
	git commit --allow-empty -m "init"
lint:
	swiftlint
clean:
	swift package --build-path ../../.build clean
build:
	swift build --build-path ../../.build -Xcc -F../../Frameworks
resolve:
	swift package --build-path ../../.build resolve
update:
	swift package --build-path ../../.build update
test:
	swift test
project:
	swift package generate-xcodeproj --xcconfig-overrides StitchCoreSDK.xcconfig
prepare: git update project
