#!/usr/bin/env python3
"""Install hash-verified local Vazirmatn TTF assets for offline Flutter builds."""

from __future__ import annotations

import hashlib
import urllib.request
from pathlib import Path

REVISION = "6e553e33489a8f9dfaccc76860a2e3f3c1e66de7"
FILES = {
    "Vazirmatn-Regular.ttf": "64e4a8189557a17b63fd7a77794207483e592972",
    "Vazirmatn-Medium.ttf": "1e08dd54d90a4879451ef0f80fe0d8068fb7462f",
    "Vazirmatn-Bold.ttf": "efa9b095da01d299310bdcae293e24e657fe6da9",
    "Vazirmatn-ExtraBold.ttf": "380bd15866f3364d7c34af1cbd3c15a2e209dfee",
    "OFL.txt": "be66b3824e9772e75141e631695c5256f105fb57",
}


def git_sha1(content: bytes) -> str:
    return hashlib.sha1(f"blob {len(content)}\0".encode("ascii") + content).hexdigest()


def main() -> None:
    folder = Path(__file__).resolve().parent.parent / "assets" / "fonts"
    folder.mkdir(parents=True, exist_ok=True)
    base = f"https://raw.githubusercontent.com/rastikerdar/vazirmatn/{REVISION}/"
    for filename, expected_sha in FILES.items():
        destination = folder / filename
        if destination.exists() and git_sha1(destination.read_bytes()) == expected_sha:
            print(f"Verified local font asset: {filename}")
            continue
        source = f"fonts/ttf/{filename}" if filename.endswith(".ttf") else filename
        request = urllib.request.Request(base + source, headers={"User-Agent": "PixelSaz-Pro-Build/1.0"})
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()
        if git_sha1(content) != expected_sha:
            raise RuntimeError(f"Integrity check failed: {filename}")
        destination.write_bytes(content)
        print(f"Downloaded and verified: {filename} ({len(content)} bytes)")


if __name__ == "__main__":
    main()
