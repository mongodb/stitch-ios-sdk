# Note on Multithreading

Many of the functions in `StitchCore_iOS`, especially network requests, can inherently take a long time. For this reason, `StitchCore_iOS` automatically queues these potentially long-running operations on the default background `DispatchQueue` so they don't block the main thread.

The main implication of this is that if you'd like to perform UI-related actions in a network request's completion handler, you must dispatch those actions back to the main thread. See [this page](https://developer.apple.com/documentation/code_diagnostics/main_thread_checker) in Apple's documentation for more information.

## PromiseKit

[PromiseKit](https://github.com/mxcl/PromiseKit) is a popular Swift library for asynchronous programming that allows developers to represent and interact with asynchronous operations as "Promises", similar to ES6 JavaScript. If you are using PromiseKit in your project, the Stitch iOS SDK offers a `StitchCore/PromiseKit` module containing extensions that allow you to call asynchronous operations in the SDK which return Promises rather than accepting a completion handler.
