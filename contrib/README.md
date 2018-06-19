#### Contribution Guide

### Summary

This project follows [Semantic Versioning 2.0](https://semver.org/). In general, every release is associated with a tag and a changelog. `master` serves as the mainline branch for the project and represent the latest state of development.

### Adding a new module

To add a new module the Stitch workspace, use this procedure.

1. `mkdir <module name>`
2. cd `<module_name>`
3. `swift package init`
4. `rm Tests/LinuxMain.swift Tests/<module_name>Tests/XCTestManifests.swift`
5. Add the dependency `.package(url: "../StitchCore", .branch("master"))`
6. Add any other necessary dependencies
7. Copy the `.xccconfig` file from `StitchCore` and rename it to `<module_name>.xcconfig` This will ensure that the necessary include paths and linker flags to compile with `libbson` and `libmongoc` are added when running `make`.
8. Copy the `Makefile` from `StitchCore`, and change all instances of `StitchCore` to the name of the new module.
9. Update the `Makefile` in the root directory to include the make tasks for the newly created module.
10. Add the following the `.gitignore` for the entire project:
    ```
    <module name>/Packages/
    <module name>/Package.pins
    <module name>/Package.resolved
    <module name>/.build/
    <module name>/<module name>.xcodeproj/
    ```
11. Run `make` in the root directory
12. Drag the generated XCode project into the `Stitch` workspace, being careful not to make it a subproject of any other project.
13. In the Evergreen task for for `run_ios_tests`, add the following build commands:
    ```
    echo "!building <module-name>!"
    xcodebuild -workspace Stitch.xcworkspace/ -scheme <module-name>-Package -configuration Debug -derivedDataPath build -destination "platform=iOS Simulator,name=iPhone 7,OS=11.2"
    ```


If creating an iOS-specific module to complement the module:
1. Create a new "Cocoa Touch Framework" project in XCode.
2. Give it the name `<module_name>-iOS`
3. Ensure that "Include Unit Tests" is selected
4. Ensure that you add it to the `Stitch` workspace and the `Stitch` group.
5. In the "Build Phases" for the main target, add `StitchCore_iOS.framework` and the core module on top of which you are building as dependencies in "Link Binary with Libraries".
6. In the "Build Phases" for the test target, add `StitchCoreTestUtils_iOS.framework` and `StitchCoreTestUtils.framework` as dependencies in "Link Binary with Libraries".
7. In the "Build Settings" for both the main target and test target, add the following setting for "Header Search Paths,
   ```
    //:configuration = Debug
    HEADER_SEARCH_PATHS = $(SRCROOT)/../vendor/Sources/libbson $(SRCROOT)/../vendor/Sources/libmongoc

    //:configuration = Release
    HEADER_SEARCH_PATHS = $(SRCROOT)/../vendor/Sources/libbson $(SRCROOT)/../vendor/Sources/libmongoc

    //:completeSettings = some
    HEADER_SEARCH_PATHS

   ```
   and the following setting for "Library Search Paths"
   ```
    //:configuration = Debug
    LIBRARY_SEARCH_PATHS = $(SRCROOT)/../vendor/MobileSDKs/iphoneos/lib

    //:configuration = Release
    LIBRARY_SEARCH_PATHS = $(SRCROOT)/../vendor/MobileSDKs/iphoneos/lib

    //:completeSettings = some
    LIBRARY_SEARCH_PATHS

   ```

8. In the "General" settings for the main target, set the iOS Deployment target to `8.0`.

9. In the Evergreen task for `run_ios_tests`, add the following commands:
    ```
    echo "!testing <module-name>-iOS!"
    xcodebuild test -workspace Stitch.xcworkspace/ -scheme <module-name>-iOS -configuration Debug -derivedDataPath build -destination "id=$SIM_UUID"
    ```
10. In "Product" -> "Scheme" -> "Manage Schemes", scroll to the newly created module `<module_name>-iOS`, and select the "Shared" checkbox.


### Publishing a New SDK version
```bash
# update podspecs for affected modules in relation to semver as it applies
# Only StitchCore and pods depending on it are updated. For example this
# excludes ExtendedJson. So if that were to update, you must manually bump
# its version.

# run bump_version.bash with either patch, minor, or major
./bump_version.bash <patch|minor|major>

# make live
git push upstream && git push upstream --tags
VERSION=`cat StitchCore.podspec | grep "s.version" | head -1 | sed -E 's/[[:space:]]+s\.version.*=.*"(.*)"/\1/'`
for spec in *.podspec ; do
    name=`echo $spec | sed -E 's/(.*)\.podspec/\1/'`
    if pod trunk info $name | grep "$VERSION" > /dev/null; then
        continue
    fi
    echo pushing $name @ $VERSION to trunk
    pod trunk push $spec
done

# send an email detailing the changes to the https://groups.google.com/d/forum/mongodb-stitch-announce mailing list
```

### Patch Versions

The work for a patch version should happen on a "support branch" (e.g. 1.2.x). The purpose of this is to be able to support a minor release while excluding changes from the mainstream (`master`) branch. If the changes in the patch are relevant to other branches, including `master`, they should be backported there. The general publishing flow can be followed using `patch` as the bump type in `bump_version`.

### Minor Versions

The general publishing flow can be followed using `minor` as the bump type in `bump_version`.

### Major Versions

The general publishing flow can be followed using `major` as the bump type in `bump_version`. In addition to this, the release on GitHub should be edited for a more readable format of key changes and include any migration steps needed to go from the last major version to this one.
