#!/bin/sh
# Runs the KretaKit tests.
#
# With Xcode installed this is just `swift test`. With only the Command Line
# Tools, SwiftPM does not find the Swift Testing macro plugin on its own, so
# the paths are passed explicitly.
set -eu
cd "$(dirname "$0")"

developer_dir="$(xcode-select -p)"
if [ -d "$developer_dir/usr/lib/swift/host/plugins/testing" ] && [ ! -d "$developer_dir/Platforms" ]; then
    frameworks="$developer_dir/Library/Developer/Frameworks"
    exec swift test "$@" \
        -Xswiftc -plugin-path -Xswiftc "$developer_dir/usr/lib/swift/host/plugins/testing" \
        -Xswiftc -F -Xswiftc "$frameworks" \
        -Xlinker -F -Xlinker "$frameworks" \
        -Xlinker -rpath -Xlinker "$frameworks"
fi
exec swift test "$@"
