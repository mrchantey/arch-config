#!/usr/bin/env python3
"""Stow shared preferences and capture/seed a private Thunderbird account snapshot."""

import argparse
import base64
import configparser
import gzip
import io
import json
import os
import re
import shutil
import sqlite3
import subprocess
import tempfile
import time
import tomllib
from contextlib import closing
from pathlib import Path, PurePosixPath

REPO = Path(__file__).resolve().parent.parent
RECORD = "THUNDERBIRD_PROFILE"
GROUP = "thunderbird"
PRIVATE_PREFIXES = (
    "mail.account.", "mail.accountmanager.", "mail.identity.",
    "mail.server.", "mail.smtp", "calendar.registry.", "ldap_2.servers.",
)
PRIVATE_KEYS = {"calendar.list.sortOrder", "mail.root.imap-rel", "mail.root.none-rel"}
LOCAL_SUFFIXES = (
    ".clientid", ".serverIDResponse", ".lastFilterTime", ".nextFilterTime",
    ".carddav.token",
)
CREDENTIAL_FILES = {"logins.json", "key4.db", "cert9.db"}
MAX_SNAPSHOT = 32 * 1024 * 1024


class SetupError(Exception):
    """An actionable error that contains no private configuration values."""


def read_prefs(path):
    if not path.exists():
        return {}
    prefs = {}
    for line in path.read_text().splitlines():
        if not line.startswith("user_pref("):
            continue
        match = re.fullmatch(r'user_pref\((".*?"), (.*)\);', line)
        if not match:
            raise SetupError("Cannot parse a Thunderbird preference, snapshot not changed.")
        try:
            prefs[json.loads(match[1])] = json.loads(match[2])
        except ValueError:
            raise SetupError("Invalid preference JSON, snapshot not changed.") from None
    return prefs


def has_accounts(profile):
    return any(re.fullmatch(r"mail\.account\.[^.]+\.server", key)
               for key in read_prefs(profile / "prefs.js"))


def read_ini(path):
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = lambda optionstr: optionstr
    config.read(path)
    return config


def selected_profile(root):
    config = read_ini(root / "profiles.ini")
    paths = {config[section]["Default"] for section in config.sections()
             if section.startswith("Install") and config[section].get("Default")}
    if len(paths) > 1:
        raise SetupError("Multiple installation defaults, use --profile to select one.")
    if paths:
        return root / paths.pop()
    profiles = [config[section] for section in config.sections()
                if section.startswith("Profile") and "Path" in config[section]]
    defaults = [profile for profile in profiles if profile.get("Default") == "1"]
    if len(defaults) == 1:
        return root / defaults[0]["Path"]
    if len(profiles) == 1:
        return root / profiles[0]["Path"]
    if profiles:
        raise SetupError("No unambiguous default profile, use --profile to select one.")
    return None


def require_stopped():
    result = subprocess.run(["pgrep", "-x", "thunderbird"], capture_output=True, check=False)
    if result.returncode == 0:
        raise SetupError("Close Thunderbird before capturing or restoring accounts.")
    if result.returncode != 1:
        raise SetupError("Could not check whether Thunderbird is running.")


def require_local(path):
    if path.resolve().is_relative_to(REPO):
        raise SetupError("Refusing to put a private Thunderbird profile inside the repo.")
    if path.is_symlink():
        raise SetupError("Thunderbird state directories must be real directories, not symlinks.")


def safe_relative(value):
    path = PurePosixPath(value)
    if not value or not path.parts or path.is_absolute() or ".." in path.parts or "\\" in value:
        raise SetupError("Snapshot contains an unsafe relative path.")
    return Path(*path.parts)


def private_pref(key):
    return (key.startswith(PRIVATE_PREFIXES) or key in PRIVATE_KEYS) and not key.endswith(LOCAL_SUFFIXES)


def portable_prefs(prefs, profile):
    portable = {}
    for key, value in prefs.items():
        if not private_pref(key):
            continue
        if key.endswith(".directory"):
            if key + "-rel" not in prefs:
                raise SetupError("An account has no profile-relative mail directory.")
            continue
        if key.endswith(".directory-rel") or key.startswith("mail.root."):
            if not isinstance(value, str) or not value.startswith("[ProfD]"):
                raise SetupError("An account uses an external mail directory, capture refused.")
            safe_relative(value.removeprefix("[ProfD]"))
        if isinstance(value, str) and (value.startswith(("/", "file:")) or str(profile) in value):
            raise SetupError("A private setting references a local file, capture refused.")
        portable[key] = value
    return portable


def database_bytes(path):
    # Include WAL contents without ever creating a plaintext database in the repo.
    with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)) as source, closing(sqlite3.connect(":memory:")) as target:
        source.backup(target)
        return target.serialize()


def capture(profile, document):
    require_stopped()
    require_local(profile)
    if not has_accounts(profile):
        raise SetupError("The selected profile has no accounts to capture.")
    files = {}
    for name in sorted(CREDENTIAL_FILES):
        path = profile / name
        if path.exists():
            content = database_bytes(path) if name.endswith(".db") else path.read_bytes()
            files[name] = base64.b64encode(content).decode()
    if ("logins.json" in files) != ("key4.db" in files):
        raise SetupError("Saved logins and their NSS key database must be captured together.")
    for directory in ("ImapMail", "Mail"):
        for path in (profile / directory).glob("**/msgFilterRules.dat"):
            files[path.relative_to(profile).as_posix()] = base64.b64encode(path.read_bytes()).decode()
    payload = {"version": 1, "prefs": portable_prefs(read_prefs(profile / "prefs.js"), profile), "files": files}
    validate_snapshot(payload)
    plaintext = json.dumps(payload).encode()
    if len(plaintext) > MAX_SNAPSHOT:
        raise SetupError("Thunderbird snapshot exceeds the size limit, snapshot not changed.")
    value = base64.b64encode(gzip.compress(plaintext, mtime=0)).decode()
    # Pipe the value, never put credentials in argv, an environment variable or terminal output.
    result = subprocess.run([
        "beet", "secrets/set", RECORD, f"--document={document}", f"--group={GROUP}",
        "--note=Thunderbird portable account settings and NSS saved-login snapshot",
        "--roll=manual:just capture-thunderbird",
    ], cwd=REPO, input=value, text=True, capture_output=True, check=False)
    if result.returncode:
        raise SetupError("Could not seal the snapshot, check beet secrets/check and the age identity.")
    print(f"Captured {len(payload['prefs'])} private preferences and {len(files)} files into secrets.toml.")


def open_snapshot(document, identity):
    index = tomllib.loads(document.read_text())
    groups = [name for name, group in index.get("groups", {}).items()
              if RECORD in group.get("secrets", {})]
    if len(groups) != 1:
        raise SetupError("Expected one THUNDERBIRD_PROFILE record in secrets.toml.")
    group = groups[0]
    result = subprocess.run(["age", "--decrypt", "--identity", str(identity)],
                            input=index["sealed"][group], text=True, capture_output=True, check=False)
    if result.returncode:
        raise SetupError("Cannot open the Thunderbird snapshot, restore the correct age identity.")
    try:
        opened = tomllib.loads(result.stdout)
        if opened["recipients"] != index["groups"][group]["recipients"]:
            raise SetupError("The secrets recipient index differs from the sealed group.")
        compressed = base64.b64decode(opened["secrets"][RECORD]["value"], validate=True)
        with gzip.GzipFile(fileobj=io.BytesIO(compressed)) as stream:
            plaintext = stream.read(MAX_SNAPSHOT + 1)
        if len(plaintext) > MAX_SNAPSHOT:
            raise SetupError("Thunderbird snapshot exceeds the size limit.")
        payload = json.loads(plaintext)
        validate_snapshot(payload)
        return payload
    except (ValueError, KeyError, TypeError, OSError, EOFError):
        raise SetupError("Invalid Thunderbird snapshot, no profile was changed.") from None


def validate_snapshot(payload):
    if payload["version"] != 1 or not isinstance(payload["prefs"], dict) or not isinstance(payload["files"], dict):
        raise SetupError("Unsupported Thunderbird snapshot format.")
    prefs = payload["prefs"]
    if not any(re.fullmatch(r"mail\.account\.[^.]+\.server", key) for key in prefs):
        raise SetupError("Thunderbird snapshot contains no accounts.")
    for key, value in prefs.items():
        if not private_pref(key) or key.endswith(".directory") or type(value) not in (str, int, bool):
            raise SetupError("Snapshot contains an unsupported preference.")
        if key.endswith(".directory-rel") or key.startswith("mail.root."):
            if not isinstance(value, str) or not value.startswith("[ProfD]"):
                raise SetupError("Snapshot contains an external mail directory.")
            safe_relative(value.removeprefix("[ProfD]"))
    files = payload["files"]
    if ("logins.json" in files) != ("key4.db" in files):
        raise SetupError("Snapshot is missing half of the saved-login/key pair.")
    for name, content in files.items():
        path = safe_relative(name)
        if name not in CREDENTIAL_FILES and not (path.parts[0] in ("Mail", "ImapMail") and path.name == "msgFilterRules.dat"):
            raise SetupError("Snapshot contains an unsupported file.")
        base64.b64decode(content, validate=True)


def write_private(path, content):
    descriptor, temporary = tempfile.mkstemp(prefix=".thunderbird-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(content)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def backup(path):
    if path.exists() or path.is_symlink():
        destination = path.with_name(path.name + f".pre-stow.{time.time_ns()}")
        path.rename(destination)
        print(f"Preserved previous {path.name} beside it as {destination.name}.")


def link_preferences(root, profile):
    if profile is None:
        return
    require_local(root)
    require_local(profile)
    template = root / "user.js"
    if not template.is_file():
        raise SetupError("Shared user.js is not stowed, run just stow-symlinks first.")
    profile.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination = profile / "user.js"
    if destination.is_symlink() and destination.resolve() == template.resolve():
        return
    backup(destination)
    destination.symlink_to(os.path.relpath(template, profile))
    print("Linked shared Thunderbird preferences, applied on the next start.")


def register_profile(root, profile):
    path = root / "profiles.ini"
    config = read_ini(path)
    relative = profile.relative_to(root).as_posix()
    for section in config.sections():
        if section.startswith("Profile"):
            config[section].pop("Default", None)
        elif section.startswith("Install"):
            config[section]["Default"] = relative
            config[section]["Locked"] = "1"
    section = next((section for section in config.sections()
                    if section.startswith("Profile") and config[section].get("Path") == relative), None)
    if section is None:
        number = 0
        while f"Profile{number}" in config:
            number += 1
        section = f"Profile{number}"
    config[section] = {"Name": "arch-config", "IsRelative": "1", "Path": relative, "Default": "1"}
    config["General"] = {"StartWithLastProfile": "1", "Version": "2"}
    save_ini(path, config)
    installs = root / "installs.ini"
    if installs.exists():
        config = read_ini(installs)
        for section in config.sections():
            config[section]["Default"] = relative
            config[section]["Locked"] = "1"
        save_ini(installs, config)


def save_ini(path, config):
    output = io.StringIO()
    config.write(output, space_around_delimiters=False)
    content = output.getvalue().encode()
    if path.exists() and path.read_bytes() == content:
        return
    if path.exists():
        # Keep the original registry in place until its atomic replacement is ready.
        saved = path.with_name(path.name + f".pre-stow.{time.time_ns()}")
        write_private(saved, path.read_bytes())
    write_private(path, content)


def seed_profile(root, payload):
    profile = root / "arch-config"
    require_local(profile)
    if profile.exists():
        if not (profile / ".arch-config-snapshot").is_file() or not has_accounts(profile):
            raise SetupError("arch-config profile already exists but is not a completed restore, leaving it untouched.")
        return profile
    staging = Path(tempfile.mkdtemp(prefix=".arch-config-", dir=root))
    try:
        prefs = dict(payload["prefs"])
        for key, value in list(prefs.items()):
            if key.endswith(".directory-rel") or key.startswith("mail.root."):
                relative = safe_relative(value.removeprefix("[ProfD]"))
                (staging / relative).mkdir(parents=True, exist_ok=True, mode=0o700)
                absolute_key = key.removesuffix("-rel")
                prefs[absolute_key] = str(profile / relative)
        text = "// Restored account snapshot. Shared preferences are in user.js.\n"
        text += "".join(f"user_pref({json.dumps(key)}, {json.dumps(value)});\n" for key, value in sorted(prefs.items()))
        write_private(staging / "prefs.js", text.encode())
        for name, content in payload["files"].items():
            destination = staging / safe_relative(name)
            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            write_private(destination, base64.b64decode(content, validate=True))
        write_private(staging / ".arch-config-snapshot", b"1\n")
        staging.rename(profile)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    return profile


def setup(root, document, identity, profile=None, new_profile=False):
    require_stopped()
    require_local(root)
    profile = profile or selected_profile(root)
    if profile and has_accounts(profile) and not new_profile:
        link_preferences(root, profile)
        print("Existing Thunderbird accounts preserved, snapshot was not reapplied.")
        return
    if not identity.is_file():
        link_preferences(root, profile)
        print("Thunderbird accounts pending age identity restoration. just setup-age-identity <backup.age> retries setup automatically.")
        return
    payload = open_snapshot(document, identity)
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    restored = seed_profile(root, payload)
    link_preferences(root, restored)
    register_profile(root, restored)
    print("Restored Thunderbird accounts into the arch-config profile, previous profiles preserved.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "link", "capture", "setup"))
    parser.add_argument("--profile", type=Path, help="Select an existing profile for capture or shared preferences")
    parser.add_argument("--new-profile", action="store_true", help="Select the restored arch-config profile without replacing existing profiles")
    args = parser.parse_args()
    root = Path.home() / ".thunderbird"
    document = REPO / "secrets.toml"
    identity = Path.home() / ".config/beet/age/keys.txt"
    os.umask(0o077)
    try:
        require_local(root)
        if args.command == "prepare":
            template = root / "user.js"
            expected = REPO / "stow/thunderbird/.thunderbird/user.js"
            if (template.exists() or template.is_symlink()) and not (template.is_symlink() and template.resolve() == expected):
                backup(template)
            root.mkdir(parents=True, exist_ok=True, mode=0o700)
        elif args.command == "setup":
            setup(root, document, identity, args.profile, args.new_profile)
        else:
            profile = args.profile or selected_profile(root)
            if args.command == "link":
                link_preferences(root, profile)
            elif profile is None:
                raise SetupError("No Thunderbird profile found to capture.")
            else:
                capture(profile.resolve(), document)
    except SetupError as error:
        parser.exit(1, f"Thunderbird setup: {error}\n")
    except (OSError, ValueError, KeyError, sqlite3.Error, configparser.Error):
        parser.exit(1, "Thunderbird setup failed while reading configuration or writing local files, no secret values were printed.\n")


if __name__ == "__main__":
    main()
