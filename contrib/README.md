#### Contribution Guide

### Summary

This project follows [Semantic Versioning 2.0](https://semver.org/). In general, every release is associated with a tag and a changelog. `master` serves as the mainline branch for the project and represent the latest state of development.

### Working with the existing repository

1. Run `pod install` at the top level directory.
2. If this fails due to a pod not being found, you may have to run `pod update` first.

### Adding a new module

To add a new module the Stitch workspace, use this procedure.

1. Create a new "Cocoa Touch Framework" project in XCode.
2. Add a new target to the podfile.
3. Add the appropriate dependencies as you would any other pod based project.
4. Run `pod install`.
5. Add the XCTest associated with your module to the appropriate scheme.

### Working with SwiftLint
This project uses SwiftLint to lint source files. CocoaPods includes SwiftLint as a dependency and the projects are set up such that each project will automatically lint its source files. 

We also recommend installing `swiftlint` separately with `brew install swiftlint`. This will allow you to run `swiftlint`, and `swiftlint autocorrect` from each project's root directory to quickly fix automatically correctable errors, and to see linter output when XCode is acting up.

#### Special Settings
To avoid getting a lot of linter warnings, make sure the following whitespace settings are enabled in the `Text Editing` Preferences in XCode:

- Automatically trim trailing whitespace
    - Including whitespace-only lines

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
