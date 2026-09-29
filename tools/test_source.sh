#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
/usr/bin/clang -Isrc -Wall -Wextra -Werror -Wno-deprecated-declarations -fno-objc-arc -framework Foundation src/FeaturedPolicy.m tests/test_policy.m -o build/test_policy
./build/test_policy
/usr/bin/clang -Isrc -Itests -Wall -Wextra -Werror -Wno-deprecated-declarations -fno-objc-arc -framework Foundation src/FeaturedPolicy.m src/FeaturedLayout.m tests/test_layout.m -o build/test_layout
./build/test_layout
/usr/bin/clang -Isrc -Itests -Wall -Wextra -Werror -Wno-deprecated-declarations -fno-objc-arc -framework Foundation -framework CoreFoundation src/FeaturedPolicy.m src/FeaturedLayout.m src/FeaturedRelay.m tests/test_relay.m -o build/test_relay
./build/test_relay
