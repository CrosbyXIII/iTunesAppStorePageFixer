#!/usr/bin/env python3
"""Build the local release from reviewed copy and the pinned device-tested payload.

No network access, device access, Git operations, or deployment occurs here.
"""
import bz2
import gzip
import hashlib
import html
import io
import json
import math
from pathlib import Path
import re
import tarfile
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
HEADINGS = ["Summary", "Description", "Features", "Compatibility", "Requirements",
            "Limitations", "Installation", "Removal and troubleshooting", "Privacy",
            "Release notes", "Credits"]


def read_inputs():
    config = json.loads((ROOT / "config/release.json").read_text())
    for key, value in config.items():
        if isinstance(value, str) and any(c in value for c in "\r\n\x00"):
            raise ValueError(f"{key}: must be one line")
    for key in ("package", "architecture"):
        if not re.fullmatch(r"[a-z0-9][a-z0-9+.-]+", config[key]):
            raise ValueError(f"Invalid {key}")
    if not re.fullmatch(r"[0-9][A-Za-z0-9.+~:-]*", config["version"]):
        raise ValueError("Invalid Debian version")
    for key in ("github_owner", "github_repo"):
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", config[key]):
            raise ValueError(f"Invalid {key}")
    base = urlparse(config["base_url"])
    if base.scheme != "https" or not base.hostname or base.query or base.fragment or not base.path.endswith("/"):
        raise ValueError("base_url must be an HTTPS directory URL ending with /")
    parts = re.split(r"^## (.+)\n", (ROOT / "PUBLIC-COPY.md").read_text(), flags=re.M)
    sections = dict(zip(parts[1::2], (s.strip() for s in parts[2::2])))
    if list(sections) != HEADINGS or len(parts[1::2]) != len(HEADINGS):
        raise ValueError("Keep all PUBLIC-COPY.md section headings in their original order")
    if any(not value for value in sections.values()):
        raise ValueError("Public copy has an empty section")
    if len(sections["Summary"]) > 160 or "\n" in sections["Summary"]:
        raise ValueError("Summary must be one line, at most 160 characters")
    return config, sections


def inline(value):
    value = html.escape(value, quote=True)
    def link(match):
        label, url = match.groups()
        # Only these web links are supported; raw HTML remains escaped.
        if not url.startswith(("https://", "http://")):
            raise ValueError("Public copy links must be http(s)")
        return f'<a href="{url}">{label}</a>'
    value = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link, value)
    value = re.sub(r"`([^`]+)`", r"<code>\1</code>", value)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", value)


def markdown(value):
    blocks = []
    for block in value.split("\n\n"):
        lines = block.splitlines()
        if all(line.startswith("- ") for line in lines):
            blocks.append("<ul>" + "".join(f"<li>{inline(line[2:])}</li>" for line in lines) + "</ul>")
        else:
            blocks.append("<p>" + inline(" ".join(lines)) + "</p>")
    return "\n".join(blocks)


def tar_bytes(entries):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.USTAR_FORMAT) as archive:
        for name, data, mode in entries:
            info = tarfile.TarInfo("./" + name)
            info.size, info.mode = len(data), mode
            info.mtime, info.uid, info.gid = 0, 0, 0
            info.uname = info.gname = "root"
            archive.addfile(info, io.BytesIO(data))
    return gzip.compress(stream.getvalue(), compresslevel=9, mtime=0)


def ar_bytes(entries):
    output = bytearray(b"!<arch>\n")
    for name, data in entries:
        header = f"{name + '/':<16}{0:<12}{0:<6}{0:<6}{'100644':<8}{len(data):<10}`\n".encode("ascii")
        if len(header) != 60:
            raise ValueError("Invalid ar header")
        output.extend(header)
        output.extend(data)
        if len(data) % 2:
            output.extend(b"\n")
    return bytes(output)


def paragraph(fields):
    return "".join(f"{key}: {value}\n" for key, value in fields.items())


CSS = """*{-webkit-box-sizing:border-box;box-sizing:border-box}
html{background:#eef0f4;color:#252d3a;font-family:Helvetica,Arial,sans-serif;-webkit-text-size-adjust:100%}
body{margin:0}main,header,section,footer{display:block}a{color:#2556a9;text-decoration:underline}a:hover{color:#17356b}
.wrap{max-width:920px;margin:0 auto;padding:36px 26px}header{padding-bottom:24px;border-bottom:1px solid #d6dbe4}
.kicker{font-size:12px;font-weight:bold;letter-spacing:1.7px;color:#526581;text-transform:uppercase}
h1{font-size:35px;line-height:1.15;letter-spacing:-1.1px;margin:14px 0;word-wrap:break-word}
.lead{font-size:20px;line-height:1.5;max-width:710px}.badge{display:inline-block;font-size:12px;padding:6px 10px;border:1px solid #bbcadf;border-radius:14px;margin:0 6px 6px 0;background:#e1e9f6}
.links{line-height:2.2;margin:16px 0 0}.links a{display:inline-block;margin-right:20px}
.repo{padding:19px 22px;margin:24px 0;background:#182d50;color:#fff;border-radius:10px}.repo h2{color:#fff;margin-top:0}.repo p{margin-bottom:0;color:#d3dff3}
.repo code{display:block;font-size:15px;background:transparent;color:#fff;word-wrap:break-word;padding:0;line-height:1.6}
section{background:#fff;border:1px solid #dde1e8;border-radius:10px;padding:22px 25px;margin:16px 0}
h2{font-size:20px;line-height:1.4;margin:0 0 12px;color:#263b5d}p,li{font-size:15px;line-height:1.65}p:first-child{margin-top:0}p:last-child{margin-bottom:0}ul{margin:0;padding-left:22px}li+li{margin-top:8px}
code{font-family:Menlo,Consolas,monospace;font-size:.88em;background:#f0f3f8;padding:2px 4px;word-wrap:break-word}footer{font-size:12px;line-height:1.7;color:#657187;padding:24px 0}
@media(max-width:520px){.wrap{padding:24px 15px}h1{font-size:27px;letter-spacing:-.7px}.lead{font-size:18px}section{padding:20px 18px}.repo{padding:18px}.repo code{font-size:13px}}
"""


def main():
    config, sections = read_inputs()
    docs = ROOT / "docs"
    (docs / "debs").mkdir(parents=True, exist_ok=True)
    (docs / "depiction").mkdir(exist_ok=True)
    github = f'https://github.com/{config["github_owner"]}/{config["github_repo"]}'
    payload = []
    for name, checksum in config["payload_sha256"].items():
        if name not in ("FeaturedRepair.dylib", "FeaturedRepair.plist"):
            raise ValueError("Unexpected payload file")
        data = (ROOT / "payload" / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != checksum:
            raise ValueError(f"{name}: differs from the pinned device-tested payload")
        payload.append((f"Library/MobileSubstrate/DynamicLibraries/{name}", data, 0o755 if name.endswith(".dylib") else 0o644))
    if len(payload) != 2:
        raise ValueError("Both tweak files are required")
    payload.append((f'usr/share/doc/{config["package"]}/copyright', (ROOT / "LICENSE").read_bytes(), 0o644))
    fields = {
        "Package": config["package"], "Name": config["name"], "Version": config["version"],
        "Architecture": config["architecture"], "Section": config["section"], "Priority": "optional",
        "Maintainer": config["author"], "Author": config["author"], "Depends": config["depends"],
        "Conflicts": config["conflicts"], "Replaces": config["replaces"],
        "Installed-Size": str(sum(math.ceil(len(data) / 1024) for _, data, _ in payload)),
        "Description": sections["Summary"], "Homepage": config["base_url"],
        "Depiction": config["base_url"] + "depiction/", "Tag": "role::enduser"
    }
    control = tar_bytes([("control", paragraph(fields).encode(), 0o644)])
    package = ar_bytes([("debian-binary", b"2.0\n"), ("control.tar.gz", control), ("data.tar.gz", tar_bytes(payload))])
    filename = f'{config["package"]}_{config["version"]}_{config["architecture"]}.deb'
    (docs / "debs" / filename).write_bytes(package)
    index = dict(fields)
    index.update({"Filename": "debs/" + filename, "Size": str(len(package)),
                  "MD5sum": hashlib.md5(package).hexdigest(), "SHA1": hashlib.sha1(package).hexdigest(),
                  "SHA256": hashlib.sha256(package).hexdigest()})
    packages = (paragraph(index) + "\n").encode()
    for name, data in [("Packages", packages), ("Packages.gz", gzip.compress(packages, mtime=0)),
                       ("Packages.bz2", bz2.compress(packages))]:
        (docs / name).write_bytes(data)
    release = paragraph({"Origin": config["repo_label"], "Label": config["repo_label"], "Suite": "stable",
                         "Version": "1.0", "Codename": "ios5", "Architectures": config["architecture"],
                         "Components": "main", "Description": sections["Summary"]})
    for field, algorithm in [("MD5Sum", "md5"), ("SHA1", "sha1"), ("SHA256", "sha256")]:
        release += field + ":\n"
        for name in ("Packages", "Packages.gz", "Packages.bz2"):
            data = (docs / name).read_bytes()
            release += f" {hashlib.new(algorithm, data).hexdigest()} {len(data)} {name}\n"
    (docs / "Release").write_text(release)
    (docs / ".nojekyll").touch()
    (docs / "style.css").write_text(CSS)
    (docs / "LICENSE.txt").write_bytes((ROOT / "LICENSE").read_bytes())
    escaped = {k: html.escape(v, quote=True) for k, v in config.items() if isinstance(v, str)}
    content = "\n".join(f'<section id="{heading.lower().replace(" ", "-")}"><h2>{html.escape(heading)}</h2>{markdown(sections[heading])}</section>' for heading in HEADINGS if heading != "Summary")
    for relative, prefix in (("index.html", ""), ("depiction/index.html", "../")):
        page = f'''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="{html.escape(sections['Summary'], quote=True)}">
<title>{escaped['name']}</title><link rel="stylesheet" href="{prefix}style.css"></head>
<body><main class="wrap"><header><div class="kicker">Legacy iPad · Community project</div>
<h1>{escaped['name']}</h1><p class="lead">{inline(sections['Summary'])}</p>
<span class="badge">Beta {escaped['version']}</span><span class="badge">iPad 1 · iOS 5.1.1</span><span class="badge">MIT · Free</span>
<p class="links"><a href="{prefix}debs/{filename}">Download .deb</a><a href="{github}">Source on GitHub</a><a href="{github}/issues">Report an issue</a></p></header>
<div class="repo"><h2>Cydia source</h2><code>{escaped['base_url']}</code><p>Add this address in Cydia → Sources → Edit → Add.</p></div>
{content}<footer>By {escaped['author']} · <a href="{prefix}LICENSE.txt">MIT license</a> · <a href="{github}/blob/main/TESTING.md">Test environment and verification limits</a></footer>
</main></body></html>
'''
        (docs / relative).write_text(page)
    readme = f'# {config["name"]}\n\n{sections["Summary"]}\n\n'
    readme += f'**Beta {config["version"]} · iPad 1 · iOS 5.1.1 · MIT**\n\n'
    readme += f'Cydia source: `{config["base_url"]}`\n\n'
    readme += f'[Package and instructions]({config["base_url"]}) · [Support]({github}/issues) · [Build guide](BUILDING.md) · [Test environment](TESTING.md)\n\n'
    readme += '\n\n'.join(f'## {heading}\n\n{sections[heading]}' for heading in HEADINGS if heading != "Summary")
    readme += '\n\n---\n\nGenerated by `tools/build_repository.py`. Edit `PUBLIC-COPY.md` and regenerate to update this README and the public pages.\n'
    (ROOT / "README.md").write_text(readme)
    print(f"Built {filename} ({len(package):,} bytes), indexes, README, and public pages. Nothing published.")


if __name__ == "__main__":
    main()
