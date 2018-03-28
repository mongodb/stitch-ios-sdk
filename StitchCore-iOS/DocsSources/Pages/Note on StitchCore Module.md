# Note on StitchCore Module

When building iOS applications with MongoDB Stitch, the only Swift module you'll need to import is `Stitch_iOS`. However, some of the protocols, classes, and enums you'll be interacting with are from an internal module called `StitchCore`. These constructs are documented separately here (link TODO).

`StitchCore` implements the internal logic of actually communicating with the MongoDB Stitch server, but you should never import `StitchCore` directly. All of the constructs from `StitchCore` that you would need to interact with are automatically imported for you when you import `Stitch_iOS`
