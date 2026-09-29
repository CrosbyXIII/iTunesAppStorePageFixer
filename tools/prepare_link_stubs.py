"""Make armv7-only link stubs from the legacy SDK for modern Apple's linker.

The SDK combines simulator/device exports and contains a missing liblaunch
re-export. Flatten libSystem's available exports; keep Foundation and Objective-C
exports in their real libraries. These are link metadata, not device binaries.
Requires PyYAML. The final binary's imported symbols are inspected separately.
"""
from pathlib import Path
import argparse
import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('sdk', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
sdk, out = args.sdk.resolve(), args.output.resolve()
targets = [
    ('usr/lib/libSystem.tbd', list((sdk / 'usr/lib/system').glob('*.tbd'))),
    ('usr/lib/libobjc.tbd', []),
    ('System/Library/Frameworks/Foundation.framework/Foundation.tbd', []),
    ('System/Library/Frameworks/CoreFoundation.framework/CoreFoundation.tbd', []),
    ('System/Library/Frameworks/CFNetwork.framework/CFNetwork.tbd', []),
]
for relative, extra in targets:
    source = yaml.safe_load((sdk / relative).read_text())
    merged = {}
    for path in [sdk / relative] + extra:
        data = yaml.safe_load(path.read_text())
        for exports in data.get('exports', []):
            if 'armv7' not in exports.get('archs', []):
                continue
            for key in ('symbols', 'weak-def-symbols', 'objc-classes', 'objc-ivars'):
                merged.setdefault(key, set()).update(exports.get(key, []))
    exports = {'archs': ['armv7']}
    exports.update({key: sorted(value) for key, value in merged.items() if value})
    if relative.endswith('/Foundation.tbd'):
        # NSURLProtocol lived in Foundation on iOS 5, before moving to CFNetwork.
        exports.setdefault('objc-classes', []).append('_NSURLProtocol')
    if relative.endswith('/libobjc.tbd'):
        exports['objc-classes'] = [x for x in exports.get('objc-classes', []) if x != '_NSObject']
    if relative.endswith('/CoreFoundation.tbd'):
        # NSObject's class/metaclass were exported by CoreFoundation on iOS 5.
        exports.setdefault('objc-classes', []).append('_NSObject')
    result = {'archs': ['armv7'], 'platform': 'ios',
              'install-name': source['install-name'],
              'current-version': source.get('current-version', 1),
              'compatibility-version': source.get('compatibility-version', 1),
              'exports': [exports]}
    path = out / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(yaml.safe_dump(result, explicit_start=True, explicit_end=True, sort_keys=False))
