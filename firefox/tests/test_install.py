import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("firefox_install", ROOT / "install.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class FirefoxInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.profile = self.home / "Profiles" / "test.default-release"
        self.profile.mkdir(parents=True)

    def test_discovers_only_registered_release_profiles(self):
        nightly = self.home / "Profiles" / "test.default-nightly"
        nightly.mkdir()
        (self.home / "profiles.ini").write_text(
            "[Profile0]\nName=default-release\nIsRelative=1\nPath=Profiles/test.default-release\n"
            "[Profile1]\nName=default-nightly\nIsRelative=1\nPath=Profiles/test.default-nightly\n"
            "[Install123]\nDefault=Profiles/test.default-nightly\n"
        )
        self.assertEqual(installer.discover_profiles(self.home), [self.profile])

    def test_absolute_profiles_and_missing_profiles(self):
        (self.home / "profiles.ini").write_text(
            f"[Profile0]\nName=default-release\nIsRelative=0\nPath={self.profile}\n"
            "[Profile1]\nName=default-release\nIsRelative=1\nPath=Profiles/missing\n"
        )
        self.assertEqual(installer.discover_profiles(self.home), [self.profile])

    def test_no_profiles_is_a_noop(self):
        self.assertEqual(installer.discover_profiles(self.home), [])
        result = subprocess.run(
            [sys.executable, str(ROOT / "install.py"), "--firefox-home", str(self.home)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.profile / "chrome").exists())

    def test_fresh_install_and_rerun(self):
        installer.install_profile(self.profile)
        chrome = self.profile / "chrome"
        for name in installer.STYLES:
            self.assertTrue((chrome / name).is_symlink())
            self.assertEqual((chrome / name).resolve(), ROOT / "chrome" / name)
        before = {p: p.lstat().st_mtime_ns for p in self.profile.rglob("*")}
        installer.install_profile(self.profile)
        self.assertEqual(before, {p: p.lstat().st_mtime_ns for p in self.profile.rglob("*")})

    def test_preserves_css_preferences_and_local_backups(self):
        chrome = self.profile / "chrome"
        chrome.mkdir()
        css = '@charset "UTF-8";\n@import url("custom.css");\n@namespace url("test");\n#nav-bar { color: red; }\n'
        prefs = 'user_pref("some.setting", 42);\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", false);\n'
        (chrome / "userChrome.css").write_text(css)
        (self.profile / "user.js").write_text(prefs)
        (chrome / "classic-dark.css").write_text("old custom colors")
        (chrome / "classic-dark.css.pre-dotfiles").write_text("older backup")
        installer.install_profile(self.profile)
        merged = (chrome / "userChrome.css").read_text()
        self.assertEqual(merged, (
            '@charset "UTF-8";\n'
            '@import url("classic-dark.css");\n'
            '@import url("tab-close-button.css");\n'
            '@import url("custom.css");\n'
            '@namespace url("test");\n'
            '#nav-bar { color: red; }\n'
        ))
        self.assertEqual((chrome / "userChrome.css.pre-dotfiles").read_text(), css)
        self.assertEqual((self.profile / "user.js.pre-dotfiles").read_text(), prefs)
        self.assertEqual((self.profile / "user.js").read_text(), prefs + (
            'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n'
        ))
        self.assertEqual((chrome / "classic-dark.css.pre-dotfiles").read_text(), "older backup")
        self.assertEqual((chrome / "classic-dark.css.pre-dotfiles.1").read_text(), "old custom colors")
        before = merged
        installer.install_profile(self.profile)
        self.assertEqual((chrome / "userChrome.css").read_text(), before)

    def test_migrates_previous_standalone_install_without_duplicate_imports(self):
        chrome = self.profile / "chrome"
        chrome.mkdir()
        for name in installer.STYLES:
            (chrome / name).write_bytes((ROOT / "chrome" / name).read_bytes())
        (chrome / "userChrome.css").write_text(installer.IMPORTS)
        (self.profile / "user.js").write_text(installer.PREFERENCE + "\n")
        installer.install_profile(self.profile)
        self.assertFalse((chrome / "userChrome.css.pre-dotfiles").exists())
        self.assertFalse((self.profile / "user.js.pre-dotfiles").exists())
        self.assertTrue((chrome / "classic-dark.css.pre-dotfiles").exists())

    def test_rejects_shared_loader_and_user_js_before_any_change(self):
        for relative in ["user.js", "chrome/userChrome.css", "chrome"]:
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as directory:
                profile = Path(directory) / "profile"
                profile.mkdir()
                target = Path(directory) / "shared"
                if relative == "chrome":
                    target.mkdir()
                else:
                    target.write_text("keep me")
                path = profile / relative
                path.parent.mkdir(exist_ok=True)
                path.symlink_to(target)
                with self.assertRaises(ValueError):
                    installer.install_profile(profile)
                self.assertTrue(path.is_symlink())
                self.assertFalse((profile / "chrome/classic-dark.css").exists())
                if target.is_file():
                    self.assertEqual(target.read_text(), "keep me")

    def test_preserves_replaced_stylesheet_symlink_and_its_target(self):
        chrome = self.profile / "chrome"
        chrome.mkdir()
        target = self.home / "old.css"
        target.write_text("keep original")
        (chrome / "classic-dark.css").symlink_to(target)
        installer.install_profile(self.profile)
        self.assertEqual(target.read_text(), "keep original")
        self.assertEqual((chrome / "classic-dark.css.pre-dotfiles").resolve(), target)

    def test_rejects_non_profile_and_directory_collisions(self):
        with self.assertRaises(ValueError):
            installer.install_profile(self.home / "missing")
        chrome = self.profile / "chrome"
        chrome.mkdir()
        (chrome / "tab-close-button.css").mkdir()
        with self.assertRaises(ValueError):
            installer.install_profile(self.profile)
        self.assertFalse((chrome / "classic-dark.css").exists())

    def test_explicit_profile_cli(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "install.py"), "--profile", str(self.profile)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.profile / "chrome/classic-dark.css").is_symlink())


if __name__ == "__main__":
    unittest.main()
