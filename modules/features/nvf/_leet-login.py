# _leet-login.py
# stdlib-only helper behind `:DendriticLeetLogin`.
# Extracts LeetCode session cookies from a Chromium-family profile
# (Brave/Chromium/Chrome share the SQLite cookie layout; on Linux the
# values are stored in plaintext, so no keychain decryption is needed).
# Packaged by modules/features/nvf/default.nix via
# pkgs.writers.writePython3Bin as `dendritic-leet-login` (no new
# runtime dependencies). The Lua side
# (_dendritic-leetcode/lua/dendritic-leetcode/browser.lua) launches the
# browser against an isolated profile dir and polls `extract` until the
# user has logged in.
"""Extract LeetCode cookies from a Chromium-profile cookie database."""

import argparse
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path

WANT = ("LEETCODE_SESSION", "csrftoken")

# Newer Chromium layouts nest the store under Network/.
CANDIDATES = (
    Path("Default") / "Network" / "Cookies",
    Path("Default") / "Cookies",
)


def find_db(profile: Path) -> Path | None:
    """Return the first cookie DB that exists under profile."""
    for rel in CANDIDATES:
        cand = profile / rel
        if cand.is_file():
            return cand
    return None


def extract(profile: Path) -> str | None:
    """Return 'LEETCODE_SESSION=..; csrftoken=..' or None."""
    db = find_db(profile)
    if db is None:
        return None
    # Copy first: the live DB is locked while the browser runs, and
    # -wal/-shm siblings may hold the freshest rows.
    with tempfile.NamedTemporaryFile(suffix=".db", delete=True) as tmp:
        try:
            shutil.copyfile(db, tmp.name)
            for suffix in ("-wal", "-shm", "-journal"):
                sidecar = Path(str(db) + suffix)
                if sidecar.is_file():
                    shutil.copyfile(sidecar, tmp.name + suffix)
        except OSError:
            return None
        try:
            con = sqlite3.connect(f"file:{tmp.name}?mode=ro", uri=True)
        except sqlite3.Error:
            return None
        try:
            try:
                rows = con.execute(
                    "SELECT name, value FROM cookies"
                    " WHERE host_key LIKE '%leetcode.com'"
                ).fetchall()
            except sqlite3.Error:
                return None
        finally:
            con.close()
    got = {name: value for name, value in rows if name in WANT and value}
    if all(key in got for key in WANT):
        session = got["LEETCODE_SESSION"]
        csrf = got["csrftoken"]
        return f"LEETCODE_SESSION={session}; csrftoken={csrf}"


def main(argv: list[str] | None = None) -> int:
    """CLI entry point; 0 with the cookie on stdout, 1 when absent."""
    parser = argparse.ArgumentParser(
        description="Extract LeetCode session cookies from a Chromium profile."
    )
    parser.add_argument("command", choices=("extract",))
    parser.add_argument("--profile-dir", required=True, type=Path)
    args = parser.parse_args(argv)
    if args.command == "extract":
        cookie = extract(args.profile_dir)
        if cookie is None:
            return 1
        sys.stdout.write(cookie + "\n")
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
