import unittest

from prepare_android import PACKAGE_NAME, metadata, pubspec_version
from publish_android import check_history


class AndroidReleaseTests(unittest.TestCase):
    def setUp(self):
        self.badging = (
            f"package: name='{PACKAGE_NAME}' versionCode='9' versionName='0.6.3'\n"
            "sdkVersion:'24'\n"
        )
        self.signer = "a" * 64
        self.signature = f"Signer #1 certificate SHA-256 digest: {self.signer}"

    def test_manifest_uses_actual_apk_and_signature(self):
        result = metadata(self.badging, self.signature, b"test apk bytes", "Notas", "0.6.3", 9)
        self.assertEqual(result["schemaVersion"], 1)
        self.assertEqual(result["packageName"], PACKAGE_NAME)
        self.assertEqual(result["versionCode"], 9)
        self.assertEqual(result["signingCertSha256"], self.signer)
        self.assertEqual(result["size"], 14)
        self.assertEqual(len(result["sha256"]), 64)
        self.assertTrue(result["apkUrl"].endswith("/v0.6.3/aurora-calculadora-farmaceutica-v0.6.3-android.apk"))

    def test_never_publish_wrong_app_or_version_or_signer(self):
        checks = [
            (self.badging.replace(PACKAGE_NAME, "evil.app"), self.signature, "0.6.3", 9),
            (self.badging, self.signature, "0.6.2", 9),
            (self.badging, self.signature, "0.6.3", 8),
            (self.badging, "not signed", "0.6.3", 9),
        ]
        for badging, signature, version, code in checks:
            with self.subTest(version=version, code=code):
                with self.assertRaises(ValueError):
                    metadata(badging, signature, b"apk", "Notas", version, code)

    def test_pubspec_parses_version_and_build(self):
        self.assertEqual(pubspec_version("name: test\nversion: 0.6.3+9\n"), ("0.6.3", 9))

    def test_signer_change_is_blocked(self):
        current = dict(
            packageName=PACKAGE_NAME,
            versionName="0.6.3",
            versionCode=9,
            signingCertSha256=self.signer,
            sha256="1" * 64,
        )
        released = [{"tag_name": "v0.6.2", "draft": False, "prerelease": False}]
        prior = dict(current, versionName="0.6.2", versionCode=8,
                     signingCertSha256="b" * 64, sha256="2" * 64)
        with self.assertRaisesRegex(ValueError, "Signer changed"):
            check_history(current, released, lambda _: prior)

    def test_identical_previous_release_is_idempotent(self):
        current = dict(
            packageName=PACKAGE_NAME, versionName="0.6.3", versionCode=9,
            signingCertSha256=self.signer, sha256="1" * 64,
        )
        published = [{"tag_name": "v0.6.3", "draft": False, "prerelease": False}]
        self.assertEqual(check_history(current, published, lambda _: current),
                         "already-published")

    def test_version_code_cannot_roll_back(self):
        current = dict(
            packageName=PACKAGE_NAME, versionName="0.6.3", versionCode=9,
            signingCertSha256=self.signer, sha256="1" * 64,
        )
        prior = dict(current, versionCode=9, versionName="0.6.2")
        with self.assertRaisesRegex(ValueError, "increase"):
            check_history(current, [{"tag_name": "v0.6.2"}], lambda _: prior)

    def test_new_first_release_is_allowed(self):
        current = dict(
            packageName=PACKAGE_NAME, versionName="0.6.3", versionCode=9,
            signingCertSha256=self.signer, sha256="1" * 64,
        )
        self.assertEqual(check_history(current, [], lambda _: None), "publish")


if __name__ == "__main__":
    unittest.main()
