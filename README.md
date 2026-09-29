# iTunesAppStorePageFixer

Restore browsing pages in the original iOS 5 App Store and iTunes Store.

**Beta 0.3.0~beta1 · iPad 1 · iOS 5.1.1 · MIT**

Cydia source: `https://crosbyxiii.github.io/iTunesAppStorePageFixer/`

[Package and instructions](https://crosbyxiii.github.io/iTunesAppStorePageFixer/) · [Support](https://github.com/CrosbyXIII/iTunesAppStorePageFixer/issues) · [Build guide](BUILDING.md) · [Test environment](TESTING.md)

## Description

iTunesAppStorePageFixer brings supported store browsing pages back to the original iPad. It reads Apple's available catalog data and displays it in grids that fit portrait and landscape, with links to the original product pages.

This is a community project by CrosbyXII, released as a free, open-source beta under the MIT license.

## Features

- App Store Featured with an iPad-sized app grid.
- Top Charts with iPad Paid, Free, and Top Grossing rankings and page navigation.
- App Store Categories and subcategories.
- iTunes Music, Movies, TV Shows, and Audiobooks browsing.
- A top-podcast directory in the existing Podcasts tab, using Apple's public feed.
- Original product links and layouts that adapt when the iPad rotates.

## Compatibility

**Tested on iPad 1 running iOS 5.1.1 with a jailbreak and Cydia Substrate.** Other iPads and iPhones have not been verified. This package is restricted to iOS 5.1.1; the architecture label `iphoneos-arm` is the legacy package format, not a claim of iPhone support.

The included library is the same build tested on the original iPad. The package version is 0.3.0~beta1; internal diagnostic messages identify the library as v0.3.0.

## Requirements

- A jailbroken iPad 1 on iOS 5.1.1 with Cydia Substrate.
- TLSFix 1.1 or later, available from [the TLSFix project](https://github.com/nfzerox/TLSFix). Add its official Cydia source, `http://cydia.skyglow.es/`, before installing this package.
- Working store connectivity and suitable trusted root certificates. The test iPad had DigiCert Global Root G2 and G3 installed. Obtain certificates from [DigiCert's official certificate page](https://knowledge.digicert.com/general-information/digicert-trusted-root-authority-certificates).

This package repairs browsing pages. It is not an all-in-one repair for account sign-in, search, downloads, or certificates. Those services may need separate repairs on your device. See the repository's TESTING.md for the existing software on the test iPad and the limits of verification.

## Limitations

- Genius recommendations and iTunes U remain unchanged. This release does not restore those services or replace them with unrelated catalogs.
- The grids use current catalog data; they do not recreate Apple's historical editorial pages exactly.
- An app appearing in the catalog does not mean it supports iOS 5 or has an older version available. The tweak does not make modern apps compatible.
- Product availability, account access, downloads, and media playback still depend on Apple and the content provider. These are not guaranteed by this tweak.
- This is a beta tested on one previously repaired iPad. A fresh-device installation has not been verified. Apple can change or remove the endpoints used by the tweak.

## Installation

- Add the TLSFix source listed above and install the prerequisites.
- In Cydia, open Sources, tap Edit, then Add. Enter the repository address shown on this page and refresh.
- Fully close App Store and iTunes from the multitasking bar.
- Search Cydia for `iTunesAppStorePageFixer`, install it, and follow any restart prompt Cydia shows.
- Reopen the stores and test Featured, Top Charts, Categories, and the supported iTunes sections.

Use the same close-and-reopen procedure when updating. If Cydia cannot download the repository over HTTPS, its TLS or certificate support may need repair first.

## Removal and troubleshooting

Close both store apps, remove iTunesAppStorePageFixer through Cydia, then reopen them. Removal restores their previous page behavior and leaves your other store repairs installed.

If either store crashes after installation, disable this tweak or remove it in Cydia before retrying. If the device becomes unresponsive, force restart with Home and Sleep/Wake, then hold Volume Up during startup to disable Substrate tweaks temporarily. Remove the package before returning to normal operation.

When reporting a problem, include your device model, iOS version, package version, affected tab, and other store/TLS tweaks. Do not post passwords, verification codes, account details, or full device logs.

## Privacy

The tweak has no analytics or developer-operated proxy. Catalog requests go to Apple. Fresh requests for the public podcast and chart feeds omit account authorization headers and disable cookies. It does not patch sign-in or purchase endpoints or disable certificate checks.

Small local diagnostic files record request hosts and paths, format choices, response sizes, and errors. The tweak does not deliberately log query strings, passwords, cookies, account identifiers, or response bodies. These messages also appear in the device's system log. Review any log before sharing it.

## Release notes

**0.3.0~beta1 — first public beta package.** Includes the tested Featured and Music grids, iPad Top Charts, Categories, Movies, TV Shows, Audiobooks, and the top-podcast directory. Source code and packaging tools are available under MIT.

## Credits

Created by CrosbyXII. Built and debugged with assistance from OpenAI Codex. Thanks to the legacy iOS community and the maintainers of Cydia Substrate and TLSFix.

This independent project is not affiliated with or endorsed by Apple. Apple operates the catalog and store services used by the tweak. Third-party dependencies retain their own licenses and are not bundled.

---

Generated by `tools/build_repository.py`. Edit `PUBLIC-COPY.md` and regenerate to update this README and the public pages.
