Avoid code comments except for TODOs or essential context.

Use Xcode's default DerivedData location for project builds. Do not pass a
temporary `-derivedDataPath`; macOS build products can leave stale Safari
extension and helper processes running from that location.
