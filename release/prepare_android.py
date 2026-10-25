"""Verify a signed Android APK and generate the public in-app update manifest.

AURORA IPTV uses a signed APK + JSON metadata + SHA-256. This implements
the same publication contract for the Calculator, with a private signing key.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REPOSITORY = "fabriciomatosqa/Aurora-calculadorafarmaceutica"
PACKAGE_NAME = "br.com.aurora.aurora_calculadora_farmaceutica"
MANIFEST_NAME = "aurora-update.json"
MAX_APK_BYTES = 512 * 1024 * 1024


def parse_badging(badging: str):
    pkg = re.search(
        r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'",
        badging,
    )
    sdk = re.search(r"sdkVersion:'(\d+)'", badging)
    if not pkg or not sdk:
        raise ValueError("Invalid APK badging output")
    package, code, name = pkg.groups()
    if package != PACKAGE_NAME or not re.fullmatch(r"\d+\.\d+\.\d+", name):
        raise ValueError("Unexpected Android package name or version")
    version_code, minimum_sdk = int(code), int(sdk.group(1))
    if version_code <= 0 or minimum_sdk < 21:
        raise ValueError("Invalid APK versionCode or minSdk")
    return package, version_code, name, minimum_sdk


def parse_signer(signature: str) -> str:
    matches = re.findall(
        r"Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]{64})",
        signature,
    )
    if len(matches) != 1:
        raise ValueError("Expected exactly one valid Android APK signer")
    return matches[0].lower()


def metadata(badging: str, signature: str, apk: bytes, notes: str, expected_version: str, expected_code: int):
    package, code, version, minimum_sdk = parse_badging(badging)
    signer = parse_signer(signature)
    if version != expected_version or code != expected_code:
        raise ValueError("APK version differs from pubspec.yaml")
    if not apk or len(apk) > MAX_APK_BYTES:
        raise ValueError("Invalid APK size")
    name = f"aurora-calculadora-farmaceutica-v{version}-android.apk"
    sha = hashlib.sha256(apk).hexdigest()
    return {
        "schemaVersion": 1,
        "packageName": package,
        "versionCode": code,
        "versionName": version,
        "minSdk": minimum_sdk,
        "apkUrl": f"https://github.com/{REPOSITORY}/releases/download/v{version}/{name}",
        "size": len(apk),
        "sha256": sha,
        "signingCertSha256": signer,
        "notes": notes.strip()[:8000],
    }


def pubspec_version(pubspec: str):
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec, re.M)
    if not match:
        raise ValueError("Expected pubspec version MAJOR.MINOR.PATCH+BUILD")
    return match.group(1), int(match.group(2))


def sdk_tools():
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk:
        raise ValueError("Android SDK environment not configured")
    installed = list((Path(sdk) / "build-tools").glob("*/aapt"))
    if not installed:
        raise ValueError("Android build-tools are missing")
    tools = max(installed, key=lambda p: tuple(int(x) for x in re.findall(r"\d+", p.parent.name)))
    return tools, tools.parent / "apksigner"


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: prepare_android.py APK_PATH DIST_DIRECTORY")
    apk_path, target = Path(sys.argv[1]), Path(sys.argv[2])
    aapt, signer = sdk_tools()
    badging = subprocess.check_output([str(aapt), "dump", "badging", str(apk_path)], text=True)
    signing = subprocess.check_output([str(signer), "verify", "--print-certs", str(apk_path)], text=True)
    version, code = pubspec_version(Path("pubspec.yaml").read_text(encoding="utf-8"))
    notes = Path("docs/RELEASE_NOTES.md").read_text(encoding="utf-8")
    data = metadata(badging, signing, apk_path.read_bytes(), notes, version, code)
    target.mkdir(parents=True, exist_ok=True)
    apk_name = f"aurora-calculadora-farmaceutica-v{version}-android.apk"
    destination = target / apk_name
    destination.write_bytes(apk_path.read_bytes())
    (target / MANIFEST_NAME).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (target / f"{apk_name}.sha256").write_text(f"{data['sha256']}  {apk_name}\n", encoding="utf-8")
    (target / "assinatura-android.txt").write_text(signing, encoding="utf-8")
    print(f"Verified v{version} ({code}), package {data['packageName']}, signature {data['signingCertSha256']}")


if __name__ == "__main__":
    main()
