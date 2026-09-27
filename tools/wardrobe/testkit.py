"""What the wardrobe's Blender tests share: their scratch folders.

Each case that builds into a folder of its own takes it from scratch_dir();
tidy() removes them all when the run ends, and leaked() names any wardrobe
folder the run left in the temp folder (a build test left ~460 MB a run).
"""

import pathlib
import shutil
import tempfile

_made = []
_before = set(pathlib.Path(tempfile.gettempdir()).glob("wardrobe_*"))


def scratch_dir(prefix):
    """A fresh temporary folder named `prefix`..., removed by tidy()."""
    path = pathlib.Path(tempfile.mkdtemp(prefix=prefix))
    _made.append(path)
    return path


def tidy():
    for path in _made:
        shutil.rmtree(path, ignore_errors=True)

    _made.clear()


def leaked():
    """The wardrobe folders in the temp folder that this run made and left."""
    return sorted(str(p) for p in set(pathlib.Path(tempfile.gettempdir()).glob("wardrobe_*")) - _before)
