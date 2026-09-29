# Building and preparing the repository

## Regenerate the package and public pages

Requirements: Python 3.9 or newer. No third-party Python modules are needed to package the already-tested payload.

```sh
python3 tools/build_repository.py
python3 tools/verify_repository.py
```

Edit `PUBLIC-COPY.md` for descriptions, credits, release notes, and instructions. Edit `config/release.json` for technical metadata. The generated files are `README.md` and the contents of `docs/`. The builder does not publish anything or modify the connected device.

`docs/` is a flat Cydia/APT repository and a static website. It includes the `.deb`, `Packages`, gzip/bzip2 indexes, and a `Release` checksum manifest. The repository is unsigned; checksums detect inconsistent downloads but are not a signature. Serve it over HTTPS. Old clients need working TLS and roots for the chosen host.

The recommended Cydia source is now **https://crosbyxiii.github.io/**, the [general CrosbyXII repository](https://github.com/CrosbyXIII/CrosbyXIII.github.io). This project's original source remains available for compatibility. After building and testing a new release, upload its `.deb` to the general repository's `packages/` folder; that repository automatically regenerates and publishes its catalog. Pushing this project's source alone does not update the general repository. `cydia_source_url` controls the recommended address displayed on these pages; `base_url` remains the URL of this project's own downloads and depiction.

The package is a classic `iphoneos-arm` package with gzip tar members, containing only the two tweak files and its copyright notice. It has no installation scripts, certificate profiles, hosts changes, or third-party libraries. Close both stores before installation/update/removal and reopen afterward. Cydia manages dependencies. Package conflicts/replaces metadata handles the optional earlier development package ID.

## Build the source on macOS

Requirements: Apple command-line build tools with armv7 support, an iPhoneOS 9.3 SDK, Python 3, and PyYAML for generating legacy link metadata. Obtain an appropriate SDK separately; it is not redistributed here. The original build used the iPhoneOS9.3 SDK in [theos/sdks](https://github.com/theos/sdks).

```sh
python3 -m venv build-env
. build-env/bin/activate
python3 -m pip install PyYAML
PAGEFIXER_SDK=/absolute/path/to/iPhoneOS9.3.sdk sh tools/build_source.sh
```

The build writes to `build/` and never overwrites `payload/`. It first runs the synthetic tests. The library targets armv7/iOS 5.0 and uses manual reference counting. The distributed package is deliberately limited to the tested iOS 5.1.1 setup. The build applies an ad-hoc signature with SHA-1 and SHA-256 digests.

Apple moved some Objective-C classes between system libraries after iOS 5. The linker stubs preserve the iOS 5 owners of NSURLProtocol and NSObject; many other classes are resolved at runtime. These details must not be removed solely to satisfy a modern SDK. A new compiler/SDK combination can change the library's imports and requires renewed device validation.

To run the tests without an iOS SDK:

```sh
sh tools/test_source.sh
```

To release a new library, test `build/FeaturedRepair.dylib` on the target device before replacing the payload and updating its expected hashes and version in `config/release.json`. Different toolchains may produce different bytes; rebuilding does not itself prove device compatibility.

## Source map

- `FeaturedPolicy`: allowlisted browsing routes and storefront format changes; excludes account, purchase, search, and iTunes U routes.
- `FeaturedLayout`: catalog parsing and the responsive HTML grids.
- `FeaturedRelay`: NSURLProtocol buffering, rendering, cancellation, timeout, and public feeds without account credentials.
- `FeaturedRepair`: Substrate hook and bounded local diagnostics.

## Publishing after review

Review all tracked files, including the copy, support instructions, credits, test limitations, and MIT license. Create the GitHub repository under your account, upload only this repository tree, and enable GitHub Pages from `main` and `/docs`. There is no deployment workflow in this draft. Enabling Pages and subsequent pushes to that branch publish the content.

Then test the real repository URL in Cydia, including installation and removal, before announcing general availability. GitHub Pages setup is described in [GitHub's publishing-source documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site). The APT structure follows [Saurik's packaging guide](https://www.saurik.com/packaging.html).
