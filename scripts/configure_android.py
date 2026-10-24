#!/usr/bin/env python3
"""Prepare Android after flutter create. No release secrets go into the repo."""
import base64
import os
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
manifest = root / "android/app/src/main/AndroidManifest.xml"
if not manifest.exists():
    sys.exit("Android template missing; run flutter create first")
xml = manifest.read_text(encoding="utf-8")
permission = '<uses-permission android:name="android.permission.INTERNET" />'
install_permission = '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />'
for p in (permission, install_permission):
    if p not in xml:
        xml = xml.replace("<application", "    " + p + "\n    <application", 1)
manifest.write_text(xml, encoding="utf-8")

names = ("AURORA_KEYSTORE_BASE64", "AURORA_KEYSTORE_PASSWORD",
         "AURORA_KEY_ALIAS", "AURORA_KEY_PASSWORD")
present = [bool(os.getenv(k)) for k in names]
if any(present) and not all(present):
    sys.exit("Incomplete signing secrets; all four are required")
if not all(present):
    print("Signing secrets absent: development APK only, no public release.")
    sys.exit(0)

gradle = root / "android/app/build.gradle.kts"
if not gradle.exists():
    sys.exit("Expected Flutter Kotlin Gradle template not found")
source = gradle.read_text(encoding="utf-8")
anchor = 'signingConfig = signingConfigs.getByName("debug")'
if anchor not in source:
    sys.exit("Unable to locate debug signingConfig in Android Gradle template")

key_path = pathlib.Path(os.getenv("RUNNER_TEMP", "/tmp")) / "aurora-release.jks"
try:
    key_path.write_bytes(base64.b64decode(os.environ["AURORA_KEYSTORE_BASE64"], validate=True))
except Exception as error:
    sys.exit("Invalid AURORA_KEYSTORE_BASE64: " + type(error).__name__)
key_path.chmod(0o600)

signing = """
    signingConfigs {
        create("auroraRelease") {
            storeFile = file(System.getenv("AURORA_KEYSTORE_PATH"))
            storePassword = System.getenv("AURORA_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("AURORA_KEY_ALIAS")
            keyPassword = System.getenv("AURORA_KEY_PASSWORD")
        }
    }
"""
source = source.replace("android {", "android {\n" + signing, 1)
source = source.replace(anchor, 'signingConfig = signingConfigs.getByName("auroraRelease")')
gradle.write_text(source, encoding="utf-8")

envfile = os.getenv("GITHUB_ENV")
if envfile:
    with open(envfile, "a", encoding="utf-8") as output:
        output.write("AURORA_RELEASE_READY=true\n")
        output.write("AURORA_KEYSTORE_PATH=" + str(key_path) + "\n")
print("Release signing configured using GitHub Actions secrets.")
