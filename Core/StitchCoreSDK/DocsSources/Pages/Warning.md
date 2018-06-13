# Warning

This module is not meant to be directly imported in your projects. Attempting to communicate with MongoDB Stitch using the internal classes and protocols defined in this module will result in undefined, unstable behavior.

If you are building an iOS app, use the `Stitch_iOS` module, and if you are building a server application or other iOS-independent application, use the `StitchServer` module.

Importing either of those modules will automatically export the `StitchCore` classes documented here.