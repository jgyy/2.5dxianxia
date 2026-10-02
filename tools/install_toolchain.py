#!/usr/bin/env python3
"""Install official stable Linux x86_64 tools and verify their release checksums."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile

def fetch(url, target=None):
    request = urllib.request.Request(url, headers={"User-Agent": "jade-meridian-toolchain"})
    with urllib.request.urlopen(request, timeout=120) as response:
        if target is None:
            return response.read().decode("utf-8")
        with target.open("wb") as output:
            shutil.copyfileobj(response, output)

def verified_download(url, checksums, filename, destination, algorithm):
    lines = [line.split() for line in checksums.splitlines() if line.strip()]
    matches = [parts[0].lower() for parts in lines if len(parts) == 2 and parts[1].lstrip("*") == filename]
    if len(matches) != 1:
        raise RuntimeError(f"Official checksum missing or ambiguous: {filename}")
    archive = destination / filename
    fetch(url, archive)
    digest = hashlib.new(algorithm)
    with archive.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    if digest.hexdigest() != matches[0]:
        archive.unlink()
        raise RuntimeError(f"Checksum mismatch: {filename}")
    return archive, digest.hexdigest()

def install_godot(destination, version):
    if version == "latest":
        release = json.loads(fetch("https://api.github.com/repos/godotengine/godot-builds/releases/latest"))
        tag = release["tag_name"]
        if release["prerelease"] or release["draft"] or not re.fullmatch(r"\d+\.\d+(?:\.\d+)?-stable", tag):
            raise RuntimeError("Latest Godot release is not stable")
    else:
        if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", version):
            raise ValueError("Invalid Godot version")
        tag = version + "-stable"
    filename = f"Godot_v{tag}_linux.x86_64.zip"
    base = f"https://github.com/godotengine/godot-builds/releases/download/{tag}"
    archive, digest = verified_download(base + "/" + filename, fetch(base + "/SHA512-SUMS.txt"), filename, destination, "sha512")
    executable = filename.removesuffix(".zip")
    with zipfile.ZipFile(archive) as source:
        if source.namelist() != [executable]:
            raise RuntimeError("Unexpected Godot archive contents")
        source.extract(executable, destination)
    binary = destination / executable
    binary.chmod(0o755)
    link = destination / "godot"
    link.unlink(missing_ok=True)
    link.symlink_to(binary.name)
    return {"version": tag, "archive": filename, "sha512": digest, "source": base}

def install_blender(destination):
    base = "https://download.blender.org/release/"
    directories = sorted(set(re.findall(r'href="(Blender(\d+)\.(\d+)/)"', fetch(base))), key=lambda item: (int(item[1]), int(item[2])), reverse=True)
    selected = None
    for directory, _, _ in directories:
        candidates = re.findall(r'href="(blender-(\d+\.\d+\.\d+)-linux-x64\.tar\.xz)"', fetch(base + directory))
        if candidates:
            filename, version = max(candidates, key=lambda item: tuple(map(int, item[1].split("."))))
            selected = (base + directory, filename, version)
            break
    if selected is None:
        raise RuntimeError("No official stable Blender Linux archive found")
    release, filename, version = selected
    archive, digest = verified_download(release + filename, fetch(release + f"blender-{version}.sha256"), filename, destination, "sha256")
    directory = filename.removesuffix(".tar.xz")
    with tarfile.open(archive) as source:
        if any(not member.name.startswith(directory + "/") and member.name != directory for member in source.getmembers()):
            raise RuntimeError("Unexpected Blender archive root")
        source.extractall(destination, filter="data")
    binary = destination / directory / "blender"
    link = destination / "blender"
    link.unlink(missing_ok=True)
    link.symlink_to(binary.relative_to(destination))
    return {"version": version, "archive": filename, "sha256": digest, "source": release}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--godot-version", default=os.environ.get("GODOT_VERSION", "latest"))
    parser.add_argument("--godot-only", action="store_true")
    args = parser.parse_args()
    destination = args.destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    evidence = {"godot": install_godot(destination, args.godot_version)}
    if not args.godot_only:
        evidence["blender"] = install_blender(destination)
    for tool in evidence:
        reported = subprocess.check_output([str(destination / tool), "--version"], text=True)
        evidence[tool]["reported_version"] = reported.splitlines()[0]
        print(evidence[tool]["reported_version"], flush=True)
    (destination / "toolchain.json").write_text(json.dumps(evidence, indent=2) + "\n")

if __name__ == "__main__":
    main()
