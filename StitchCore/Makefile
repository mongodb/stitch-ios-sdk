all:
	swift package clean
	swift package update
	swift build
project:
	swift package generate-xcodeproj --xcconfig-overrides StitchCore.xcconfig
