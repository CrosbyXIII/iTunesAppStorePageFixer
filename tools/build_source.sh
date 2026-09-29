#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
: "${PAGEFIXER_SDK:?Set PAGEFIXER_SDK to the absolute path of an iPhoneOS9.3.sdk}"
sdk="$PAGEFIXER_SDK"
test -d "$sdk/System/Library/Frameworks/Foundation.framework"
sh tools/test_source.sh
"${PAGEFIXER_PYTHON:-python3}" tools/prepare_link_stubs.py "$sdk" "$PWD/build/link-stubs"
for source in FeaturedPolicy FeaturedLayout FeaturedRelay FeaturedRepair; do
    /usr/bin/clang -target armv7-apple-ios5.0 -isysroot "$sdk" -fno-objc-arc -fno-stack-protector -Os -Wall -Wextra -Werror -Wno-deprecated-declarations -c "src/$source.m" -o "build/$source.o"
done
/usr/bin/clang -target armv7-apple-ios5.0 -isysroot "$sdk" -L"$PWD/build/link-stubs/usr/lib" -F"$PWD/build/link-stubs/System/Library/Frameworks" -dynamiclib build/FeaturedPolicy.o build/FeaturedLayout.o build/FeaturedRelay.o build/FeaturedRepair.o -framework Foundation -framework CoreFoundation -lobjc -Wl,-install_name,/Library/MobileSubstrate/DynamicLibraries/FeaturedRepair.dylib -o build/FeaturedRepair.dylib
/usr/bin/codesign --force --sign - --digest-algorithm=sha1,sha256 --timestamp=none build/FeaturedRepair.dylib
/usr/bin/codesign --verify build/FeaturedRepair.dylib
/usr/bin/otool -L build/FeaturedRepair.dylib
cp src/FeaturedRepair.plist build/FeaturedRepair.plist
echo 'Built in build/. The device-tested release payload is unchanged.'
