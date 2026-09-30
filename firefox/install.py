import argparse
import configparser
from pathlib import Path
import re
import shutil
import sys
import tempfile


ROOT = Path(__file__).resolve().parent
STYLES = ("classic-dark.css", "tab-close-button.css")
IMPORTS = "".join(f'@import url("{name}");\n' for name in STYLES)
PREFERENCE = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'


def discover_profiles(firefox_home):
    registry = firefox_home / "profiles.ini"
    if not registry.is_file():
        return []
    config = configparser.ConfigParser(interpolation=None)
    config.read(registry, encoding="utf-8")
    profiles = []
    for section in config.sections():
        if not section.startswith("Profile") or config.get(section, "Name", fallback="") != "default-release":
            continue
        value = config.get(section, "Path", fallback="")
        if not value:
            continue
        path = Path(value)
        if config.getboolean(section, "IsRelative", fallback=True):
            path = firefox_home / path
        path = path.resolve()
        if path.is_dir() and path not in profiles:
            profiles.append(path)
    return profiles


def backup(path):
    candidate = path.with_name(path.name + ".pre-dotfiles")
    index = 0
    while candidate.exists() or candidate.is_symlink():
        index += 1
        candidate = path.with_name(path.name + f".pre-dotfiles.{index}")
    shutil.copy2(path, candidate, follow_symlinks=False)
    print(f"Preserved {candidate}")


def read_text(path):
    return path.read_bytes().decode("utf-8") if path.exists() else ""


def merge_imports(text):
    active_css = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    missing = []
    for name in STYLES:
        pattern = rf'''@import\s+(?:url\(\s*)?["']{re.escape(name)}["']\s*\)?\s*;'''
        if not re.search(pattern, active_css):
            missing.append(f'@import url("{name}");\n')
    if not missing:
        return text
    header = re.match(r'\A\ufeff?(?:@charset\s+"[^"]+";[\r\n]*)?', text).end()
    prefix = text[:header]
    if prefix and not prefix.endswith(("\n", "\ufeff")):
        prefix += "\n"
    return prefix + "".join(missing) + text[header:]


def replace_text(path, text):
    if path.exists() and read_text(path) == text:
        return
    if path.exists():
        backup(path)
    with tempfile.TemporaryDirectory(prefix=".dotfiles-", dir=path.parent) as directory:
        staged = Path(directory) / path.name
        staged.write_bytes(text.encode("utf-8"))
        if path.exists():
            shutil.copymode(path, staged)
        else:
            staged.chmod(0o600)
        staged.replace(path)


def link_style(source, target):
    if target.is_symlink() and target.resolve() == source:
        return
    if target.exists() or target.is_symlink():
        backup(target)
    with tempfile.TemporaryDirectory(prefix=".dotfiles-", dir=target.parent) as directory:
        staged = Path(directory) / target.name
        staged.symlink_to(source)
        staged.replace(target)


def install_profile(profile):
    profile = profile.expanduser().resolve()
    if not profile.is_dir():
        raise ValueError(f"Firefox profile does not exist: {profile}")
    if profile.is_relative_to(ROOT.parent):
        raise ValueError("Firefox profile data must stay outside the dotfiles repository")
    chrome = profile / "chrome"
    if chrome.is_symlink() or (chrome.exists() and not chrome.is_dir()):
        raise ValueError(f"Refusing shared or non-directory chrome path: {chrome}")
    loader, prefs = chrome / "userChrome.css", profile / "user.js"
    for path in (loader, prefs):
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError(f"Refusing shared or non-file settings path: {path}")
    for name in STYLES:
        if not (ROOT / "chrome" / name).is_file():
            raise ValueError(f"Missing source stylesheet: {name}")
        target = chrome / name
        if target.exists() and not target.is_symlink() and not target.is_file():
            raise ValueError(f"Refusing non-file stylesheet target: {target}")
    css = merge_imports(read_text(loader))
    settings = read_text(prefs)
    if settings.rstrip().split("\n")[-1] != PREFERENCE:
        settings += ("\n" if settings and not settings.endswith("\n") else "") + PREFERENCE + "\n"
    chrome.mkdir(exist_ok=True)
    for name in STYLES:
        link_style(ROOT / "chrome" / name, chrome / name)
    replace_text(loader, css)
    replace_text(prefs, settings)
    print(f"Linked Firefox styles: {profile}")


def main():
    parser = argparse.ArgumentParser(description="Link local CSS into Firefox Release profiles.")
    targets = parser.add_mutually_exclusive_group()
    targets.add_argument("--profile", type=Path, help="Install into one existing profile instead of auto-discovery")
    targets.add_argument("--firefox-home", type=Path, help="Directory containing Firefox's profiles.ini")
    args = parser.parse_args()
    home = args.firefox_home or Path.home() / (
        "Library/Application Support/Firefox" if sys.platform == "darwin" else ".mozilla/firefox"
    )
    try:
        profiles = [args.profile] if args.profile else discover_profiles(home.expanduser())
        if not profiles:
            print("No existing default-release Firefox profiles; skipped")
            return
        for profile in profiles:
            install_profile(profile)
    except (OSError, ValueError, configparser.Error) as error:
        parser.exit(1, f"Firefox install failed: {error}\n")
    print("Restart Firefox to load the styles")


if __name__ == "__main__":
    main()
