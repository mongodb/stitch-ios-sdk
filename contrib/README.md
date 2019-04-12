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
6. Update the scripts in the `contrib` directory to include the newly added 
   module. This includes documentation generation, version bumping, linting 
   projects, linting pods, and publishing pods.

### Working with SwiftLint
This project uses SwiftLint to lint source files. CocoaPods includes SwiftLint as a dependency and the projects are set up such that each project will automatically lint its source files. 

We also recommend installing `swiftlint` separately with `brew install swiftlint`. This will allow you to run `swiftlint`, and `swiftlint autocorrect` from each project's root directory to quickly fix automatically correctable errors, and to see linter output when XCode is acting up.

#### Special Settings
To avoid getting a lot of linter warnings, make sure the following whitespace settings are enabled in the `Text Editing` Preferences in XCode:

- Automatically trim trailing whitespace
    - Including whitespace-only lines

### Publishing a New SDK version (MongoDB Internal Contributors Only)

1. If manual changes were made to any Podfile or podspec, run 
   `contrib/lint_pods.sh` to ensure that the pods will be published 
   successfully. This command may take a while (1-2 hours).

2. Run `contrib/bump_version.sh <patch|minor|major> <jira_ticket>`. This will 
   update the version of the SDK in all of the appropriate Podfiles, it will 
   update the version of the SDK in the root-level README.md so that it refers 
   to the latest version of the SDK, and it will open a pull request on Github
   with these changes.

3. Go to [iOS SDK](https://github.com/mongodb/stitch-ios-sdk/pulls) and 
   request a reviewer on the pull request (mandatory) before merging and 
   deleting the release branch.

4. Properly tag the release with the correct version number by running
   `git tag <VERSION>` on the master branch after merging, substituting the 
   placeholder with the appropriate package version. Once the tag is created, 
   push the tag to the upstream remote with `git push upstream <VERSION>`. 
   Depending on how your local git is configured, you may need to run
   `git push origin <VERSION>` instead.

5. Ensure that you are registered for CocoaPods Trunk on your local Mac system.
   See https://guides.cocoapods.org/making/getting-setup-with-trunk.html for
   more context on this step.

6. Run `contrib/publish_pods.sh`. This publishes all of the pods for the 
   project. This command may take a while (1-2 hours).

7. Close XCode if it is already open, and run `contrib/generate_docs.sh`. This
   generates the Jazzy documentation for the project, and publishes it to the 
   appropriate AWS S3 bucket.

8. Publish a release for the new SDK version on the GitHub repository and 
   include relevant release notes. See
   https://help.github.com/en/articles/creating-releases for context, and 
   follow the general format of our previous releases.

### Patch Versions

The work for a patch version should happen on a "support branch" (e.g. 1.2.x). The purpose of this is to be able to support a minor release while excluding changes from the mainstream (`master`) branch. If the changes in the patch are relevant to other branches, including `master`, they should be backported there. The general publishing flow can be followed using `patch` as the bump type in `bump_version.bash`.

### Minor Versions

The general publishing flow can be followed using `minor` as the bump type in `bump_version.bash`.

### Major Versions

The general publishing flow can be followed using `major` as the bump type in `bump_version.bash`. In addition to this, the release on GitHub should be edited for a more readable format of key changes and include any migration steps needed to go from the last major version to this one.
