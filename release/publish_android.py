"""Publish a complete signed Android update only after all CI checks succeed.

Mirrors the proven AURORA IPTV draft -> upload -> publish flow. Published
releases are never overwritten, and the signer must match prior releases.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from prepare_android import MANIFEST_NAME, PACKAGE_NAME, REPOSITORY


def gh(*args: str) -> str:
    return subprocess.check_output(["gh", *args], text=True).strip()


def check_history(current: dict, releases: list[dict], download_manifest):
    """Do not allow signers, Android package IDs, or version codes to change improperly."""
    existing_codes = []
    for release in releases:
        tag = release.get("tag_name", "")
        if release.get("draft") or release.get("prerelease") or not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
            continue
        previous = download_manifest(tag)
        if previous.get("packageName") != PACKAGE_NAME:
            raise ValueError("Existing release uses an incompatible package")
        if previous.get("signingCertSha256") != current["signingCertSha256"]:
            raise ValueError("Signer changed. An incompatible update must never be published.")
        existing_codes.append(previous["versionCode"])
        if tag == f"v{current['versionName']}":
            if previous["sha256"] != current["sha256"] or previous["versionCode"] != current["versionCode"]:
                raise ValueError("Version tag already exists with a different APK")
            return "already-published"
    if existing_codes and current["versionCode"] <= max(existing_codes):
        raise ValueError("New Android versionCode must increase")
    return "publish"


def main():
    target = Path("dist")
    current = json.loads((target / MANIFEST_NAME).read_text(encoding="utf-8"))
    if current["packageName"] != PACKAGE_NAME:
        raise ValueError("Unexpected application ID")
    if not re.fullmatch(r"[a-f0-9]{64}", current["signingCertSha256"]):
        raise ValueError("Malformed signing certificate digest")
    repo = os.environ["GITHUB_REPOSITORY"]
    if repo != REPOSITORY:
        raise ValueError("Unexpected target repository")
    tag = f"v{current['versionName']}"

    releases = json.loads(gh("api", f"repos/{repo}/releases?per_page=100"))
    def download(tag_name: str) -> dict:
        with tempfile.TemporaryDirectory() as folder:
            gh("release", "download", tag_name, "--repo", repo,
               "--pattern", MANIFEST_NAME, "--dir", folder)
            return json.loads((Path(folder) / MANIFEST_NAME).read_text(encoding="utf-8"))

    decision = check_history(current, releases, download)
    if decision == "already-published":
        print("Identical, compatible Android release already published.")
        return

    args = ["release", "create", tag, "--repo", repo, "--target", os.environ["GITHUB_SHA"],
            "--title", f"AURORA Calculadora Farmacêutica {tag}",
            "--notes-file", "docs/RELEASE_NOTES.md", "--draft"]
    existing = next((r for r in releases if r.get("tag_name") == tag), None)
    if existing is None:
        gh(*args)
    elif not existing.get("draft"):
        raise ValueError("Published tag with incompatible assets cannot be replaced")

    asset_name = f"aurora-calculadora-farmaceutica-{tag}-android.apk"
    filenames = [asset_name, asset_name + ".sha256", MANIFEST_NAME, "assinatura-android.txt"]
    gh("release", "upload", tag, "--repo", repo, "--clobber",
       *(str(target / n) for n in filenames))
    # Keep the release invisible until APK + manifest + checksum are complete.
    gh("release", "edit", tag, "--repo", repo, "--draft=false", "--latest")
    print(f"Published https://github.com/{repo}/releases/tag/{tag}")


if __name__ == "__main__":
    main()
