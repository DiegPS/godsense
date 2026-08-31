import importlib.abc
import importlib.machinery
import importlib.util
import os
from pathlib import Path


class _PyInstallerExtensionFinder(importlib.abc.MetaPathFinder):
    def __init__(self, root):
        self.root = Path(root)

    def find_spec(self, fullname, path=None, target=None):
        relative = Path(*fullname.split("."))
        parent = self.root / relative.parent
        stem = relative.name
        candidates = (
            parent / f"{stem}.pyd",
            parent / f"{stem}.cp311-win_amd64.pyd",
        )
        for candidate in candidates:
            if candidate.exists():
                loader = importlib.machinery.ExtensionFileLoader(fullname, str(candidate))
                return importlib.util.spec_from_file_location(fullname, candidate, loader=loader)
        return None


_runtime = os.environ.get("SCOUTR_PYTHON_RUNTIME")
if not _runtime and os.environ.get("LOCALAPPDATA"):
    _runtime = str(
        Path(os.environ["LOCALAPPDATA"])
        / "Programs"
        / "@frontendshell"
        / "resources"
        / "backend"
        / "_internal"
    )
if _runtime:
    import sys

    sys.meta_path.insert(0, _PyInstallerExtensionFinder(_runtime))
