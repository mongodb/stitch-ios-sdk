all:
	swift package clean
	swift package update
	swift build
update:
	swift package update
test:
	swift test
project:
	swift package generate-xcodeproj --xcconfig-overrides StitchCoreTestUtils.xcconfig
