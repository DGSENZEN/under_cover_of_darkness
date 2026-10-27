#!/usr/bin/env python3
"""The assets kept out of this public repository (their licences are not
recorded) but needed to play: the PS2 textures, the brush sheets, the talk
box paintings. Git never carries them, so a new checkout or worktree has
none. One store, inside the repository's own .git folder (shared by every
worktree, never committed), holds the newest copy of each; this copies them
in and out.

    python3 -I tools/local_assets.py status          what this checkout lacks
    python3 -I tools/local_assets.py pull [path...]  store -> checkouts (default: this one)
    python3 -I tools/local_assets.py pull --all      store -> every worktree
    python3 -I tools/local_assets.py push            this checkout -> store
    python3 -I tools/local_assets.py gather          every worktree -> store
    python3 -I tools/local_assets.py install-hook    fill each new worktree as it is made

A file is copied only when the other side lacks it or holds an older one:
nothing is ever deleted, and a newer copy is never written over. The .import
files go with their textures, so a texture keeps its uid in every checkout.
--sources adds the tool-only folders (the source packs and photo scans, a
few hundred MB) to any command.
"""

import os
import shutil
import subprocess
import sys

# Needed to play. A path ending in /* means each folder inside it.
PLAYING = ["textures/ps2", "textures/brushes", "assets/ui/talk/*"]
# Needed only by the texture tools (tools/textures).
SOURCES = ["textures/source", "textures/scans"]

HOOK = """#!/bin/sh
# Fills a new worktree with the assets git does not carry (tools/local_assets.py).
# post-checkout: $1 old HEAD, $2 new HEAD, $3 1 for a branch checkout. A new
# worktree's checkout comes from the null commit.
if [ "$1" = "0000000000000000000000000000000000000000" ]; then
	python3 -I "$(git rev-parse --git-common-dir)/local-assets/local_assets.py" pull "$(git rev-parse --show-toplevel)" >&2 || true
fi
"""


def git(*args, cwd="."):
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def common_dir(cwd="."):
    return os.path.abspath(os.path.join(cwd, git("rev-parse", "--git-common-dir", cwd=cwd)))


def store(cwd="."):
    return os.path.join(common_dir(cwd), "local-assets", "files")


def worktrees(cwd="."):
    lines = git("worktree", "list", "--porcelain", cwd=cwd).splitlines()
    return [line.split(" ", 1)[1] for line in lines if line.startswith("worktree ")]


def folders(root, sources):
    """The managed folders under `root` (globs expanded against it)."""
    found = []

    for path in PLAYING + (SOURCES if sources else []):
        if path.endswith("/*"):
            parent = os.path.join(root, path[:-2])

            if os.path.isdir(parent):
                found += [os.path.join(path[:-2], name) for name in sorted(os.listdir(parent))
                          if os.path.isdir(os.path.join(parent, name))]
        else:
            found.append(path)

    return found


def copy_newer(src_root, dst_root, sources, quiet=False):
    """Every managed file in src_root that dst_root lacks or holds older."""
    copied = 0

    for folder in folders(src_root, sources):
        top = os.path.join(src_root, folder)

        if not os.path.isdir(top):
            continue

        for here, _, files in os.walk(top):
            for name in files:
                if name == ".DS_Store":
                    continue

                src = os.path.join(here, name)
                dst = os.path.join(dst_root, os.path.relpath(src, src_root))

                if os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
                    continue

                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
                copied += 1

    if not quiet:
        print("%s -> %s: %d file(s)" % (src_root, dst_root, copied))

    return copied


def missing(checkout, sources):
    """Store files this checkout lacks or holds older."""
    lacking = []
    root = store(checkout)

    for folder in folders(root, sources):
        for here, _, files in os.walk(os.path.join(root, folder)):
            for name in files:
                src = os.path.join(here, name)
                dst = os.path.join(checkout, os.path.relpath(src, root))

                if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(src):
                    lacking.append(os.path.relpath(src, root))

    return lacking


def install_hook(cwd="."):
    here = os.path.join(common_dir(cwd), "local-assets")
    os.makedirs(here, exist_ok=True)
    # The hook runs this copy, so it works whatever branch a worktree is on.
    shutil.copy2(os.path.abspath(__file__), os.path.join(here, "local_assets.py"))
    hook = os.path.join(common_dir(cwd), "hooks", "post-checkout")

    if os.path.exists(hook) and "local_assets.py" not in open(hook).read():
        sys.exit("a post-checkout hook of another kind is already at %s: add the lines from HOOK to it by hand" % hook)

    with open(hook, "w") as out:
        out.write(HOOK)

    os.chmod(hook, 0o755)
    print("installed %s" % hook)


def main(argv):
    sources = "--sources" in argv
    args = [a for a in argv if a != "--sources"]

    if not args:
        sys.exit(__doc__)

    command, rest = args[0], args[1:]
    top = git("rev-parse", "--show-toplevel")

    if command == "status":
        lacking = missing(top, sources)
        print("%d file(s) missing or older here%s" % (len(lacking), ":" if lacking else ""))

        for path in lacking[:40]:
            print("  " + path)
    elif command == "pull":
        targets = worktrees() if rest == ["--all"] else (rest or [top])

        for target in targets:
            copy_newer(store(), os.path.abspath(target), sources)
    elif command == "push":
        copy_newer(top, store(), sources)
    elif command == "gather":
        for tree in worktrees():
            copy_newer(tree, store(), sources)
    elif command == "install-hook":
        install_hook()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
