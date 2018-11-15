# Note on Multithreading

Many of the functions in `StitchCore_iOS`, especially network requests, can inherently take a long time. For this reason, `StitchCore_iOS` automatically queues these potentially long-running operations on the default background `DispatchQueue` so they don't block the main thread.

The main implication of this is that if you'd like to perform UI-related actions in a network request's completion handler, you must dispatch those actions back to the main thread. See [this page](https://developer.apple.com/documentation/code_diagnostics/main_thread_checker) in Apple's documentation for more information.
