# Compatibility and verification

The release payload is the v0.3.0 library tested on a jailbroken iPad 1 (`iPad1,1`) running iOS 5.1.1. The public package is labeled `0.3.0~beta1` to distinguish the first distribution from development builds. Its dependency on `firmware (= 5.1.1)` does not verify other device models.

## What has been checked

- The working Featured/Music build was tested on the device in portrait and landscape, with product pages and search confirmed working by the tester.
- After adding the additional sections in v0.3.0, the tester reported that everything seemed to work. This was a general confirmation, not an exhaustive test of every item, playback mode, purchase, or account operation.
- Before that installation, native macOS tests covered request routing, response rendering, link preservation, large/error responses, cancellation, and omission of account headers/cookies from newly created public-feed requests.
- Thirty-three imported symbol/library pairs and eighteen dynamically resolved classes were checked against metadata from the device's iOS 5.1.1 system cache.
- Modern-browser layout checks covered portrait and landscape grids. These supplement the device test; they do not emulate iOS 5 WebKit.
- Public-source tests use synthetic catalog fixtures; private device diagnostics, account information, and downloaded Apple catalog snapshots are not included.

## Existing repairs on the test device

These describe the tested environment, not a recommendation to install every package:

| Component | Version / detail |
| --- | --- |
| Cydia Substrate | 0.9.6301 |
| TLSFix | 1.1 (`com.skyglow.tlsfix`) |
| AppStoreFix | 1.0-6 (`com.aoi.storefix`), including its existing hosts changes |
| LegacyStorePatcher / StoreEtcFix | 0.0.7-60+debug (`net.nekokawa.storeetcfix`), with a separate local correction to a null-pointer dereference in debug logging |
| StoreLoginFix | 0.0.4-1+debug (`net.nekokawa.storeloginfix`) |
| Checkmate, Store! | 1.2 (`uk.invoxiplaygames.checkmatestore`) |
| Trusted roots | DigiCert Global Root G2 and G3 |

The modified StoreEtcFix library, certificates, hosts overrides, and other third-party packages are **not included** in this project. The package declares Substrate and TLSFix dependencies. Other connectivity and account repairs depend on the device's existing setup; this project does not establish a minimal fresh-jailbreak recipe.

## Still to verify for distribution

- Install, upgrade, and removal through Cydia using the public package, rather than the direct file deployment used during development.
- Cydia fetching the actual GitHub Pages URL with the device's TLS/certificate setup, once the repository has been published.
- A fresh device without the existing repairs listed above.
- Other storefront regions, other devices, and individual content playback/download paths.

## Payload identity

SHA-256, also enforced by the package builder:

```text
0800c6981c477810b352b1657e9f2f505841d2b215c014c151684df8bc62ea7c  FeaturedRepair.dylib
11dfa80a430495c5e795190f68a4014e9d7215e5bbdd4584ef333e4a0410d70d  FeaturedRepair.plist
```

The internal filenames remain `FeaturedRepair.*` so the package replaces the development files instead of loading a second copy. The Substrate filter targets only App Store and iTunes; it does not inject into SpringBoard or itunesstored.
