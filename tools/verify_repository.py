#!/usr/bin/env python3
"""Independently inspect the generated Debian archive and APT indexes."""
import bz2
import gzip
import hashlib
from html.parser import HTMLParser
import io
import json
from pathlib import Path
import plistlib
import tarfile
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def ar_members(data):
    require(data[:8] == b"!<arch>\n", "Not a Debian ar archive")
    result, pos = {}, 8
    while pos < len(data):
        header = data[pos:pos + 60]
        require(len(header) == 60 and header[-2:] == b"`\n", "Bad ar header")
        name = header[:16].decode().strip().rstrip("/")
        size = int(header[48:58])
        require(name not in result, "Duplicate ar member")
        result[name] = data[pos + 60:pos + 60 + size]
        require(len(result[name]) == size, "Truncated ar member")
        pos += 60 + size + size % 2
    require(pos == len(data), "Unexpected trailing archive bytes")
    return result


def tar_members(data):
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        result = {}
        for item in archive:
            require(item.isfile() and item.uid == 0 and item.gid == 0, "Unexpected tar member or ownership")
            name = item.name.removeprefix("./")
            require(name not in result and not name.startswith("/") and ".." not in Path(name).parts, "Unsafe archive path")
            result[name] = (archive.extractfile(item).read(), item.mode)
        return result


def fields(data):
    return dict(line.split(": ", 1) for line in data.decode().strip().splitlines())


class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ("href", "src"):
                self.links.append(value)


def main():
    config = json.loads((ROOT / "config/release.json").read_text())
    docs = ROOT / "docs"
    data = (docs / "Packages").read_bytes()
    require(gzip.decompress((docs / "Packages.gz").read_bytes()) == data, "gzip index mismatch")
    require(bz2.decompress((docs / "Packages.bz2").read_bytes()) == data, "bzip2 index mismatch")
    index = fields(data)
    package = (docs / index["Filename"]).read_bytes()
    require(int(index["Size"]) == len(package), "Package length mismatch")
    for field, algo in (("MD5sum", "md5"), ("SHA1", "sha1"), ("SHA256", "sha256")):
        require(index[field] == hashlib.new(algo, package).hexdigest(), f"{field} mismatch")
    members = ar_members(package)
    require(list(members) == ["debian-binary", "control.tar.gz", "data.tar.gz"], "Unexpected package members")
    require(members["debian-binary"] == b"2.0\n", "Invalid Debian archive version")
    control_files = tar_members(members["control.tar.gz"])
    require(list(control_files) == ["control"], "Unexpected control scripts/files")
    control = fields(control_files["control"][0])
    require(all(index.get(k) == v for k, v in control.items()), "Control/index metadata differs")
    for key, setting in (("Package", "package"), ("Name", "name"), ("Version", "version"), ("Depends", "depends")):
        require(control[key] == config[setting], f"{key} differs from settings")
    payload = tar_members(members["data.tar.gz"])
    expected = {f"Library/MobileSubstrate/DynamicLibraries/{name}" for name in config["payload_sha256"]}
    expected.add(f'usr/share/doc/{config["package"]}/copyright')
    require(set(payload) == expected, "Unexpected package payload")
    for name, checksum in config["payload_sha256"].items():
        blob, mode = payload[f"Library/MobileSubstrate/DynamicLibraries/{name}"]
        require(hashlib.sha256(blob).hexdigest() == checksum, f"Tested {name} has changed")
        require(mode == (0o755 if name.endswith(".dylib") else 0o644), f"Wrong permissions for {name}")
    filter_data = payload["Library/MobileSubstrate/DynamicLibraries/FeaturedRepair.plist"][0]
    require(plistlib.loads(filter_data) == {"Filter": {"Bundles": ["com.apple.AppStore", "com.apple.MobileStore"]}}, "Unsafe Substrate filter")
    require(filter_data == (ROOT / "src/FeaturedRepair.plist").read_bytes(), "Source and payload filters differ")
    require(payload[f'usr/share/doc/{config["package"]}/copyright'][0] == (ROOT / "LICENSE").read_bytes(), "License mismatch")
    algo, checked = None, 0
    for line in (docs / "Release").read_text().splitlines():
        if line in ("MD5Sum:", "SHA1:", "SHA256:"):
            algo = {"MD5Sum:": "md5", "SHA1:": "sha1", "SHA256:": "sha256"}[line]
        elif line.startswith(" "):
            checksum, size, name = line.split()
            blob = (docs / name).read_bytes()
            require(algo and int(size) == len(blob) and checksum == hashlib.new(algo, blob).hexdigest(), "Release checksum mismatch")
            checked += 1
    require(checked == 9, "Missing Release checksums")
    for page in docs.rglob("*.html"):
        parser = LinkParser()
        parser.feed(page.read_text())
        for link in parser.links:
            parsed = urlparse(link)
            if parsed.scheme or link.startswith("#"):
                continue
            require(not link.startswith("/"), "Link loses GitHub Pages project prefix")
            target = (page.parent / unquote(parsed.path)).resolve()
            require(target.is_relative_to(docs) and target.exists(), f"Broken or escaping link: {page.name}: {link}")
    for directory in ("src", "config", "payload", "docs", "tests", "tools"):
        for path in (ROOT / directory).rglob("*"):
            if not path.is_file() or "__pycache__" in path.parts:
                continue
            blob = path.read_bytes()
            for marker in (b"/" + b"Users/", b"@" + b"gmail.com", b"BEGIN " + b"PRIVATE KEY", b"Crosbys" + b"-iPad"):
                require(marker not in blob, f"Private material marker in {path.relative_to(ROOT)}")
    print("PASS: Debian archive, pinned payload, metadata, permissions, app-only filter, indexes, Release hashes, and local website links")


if __name__ == "__main__":
    main()
