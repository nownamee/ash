#!/usr/bin/env python3
"""Build a project-only ZIP suitable for Godot's project manager."""

import argparse
from pathlib import Path
import zipfile

PROJECT_ROOT = Path(__file__).resolve().parents[1] / "zombie_game_3d_v3"
EXCLUDED_PARTS = {".godot", ".git", ".hoplite", "__pycache__", "tests"}


def package_project(project_root: Path, output: Path) -> None:
    if not (project_root / "project.godot").is_file():
        raise ValueError(f"Missing project.godot in {project_root}")
    files = sorted(
        path
        for path in project_root.rglob("*")
        if path.is_file()
        and not path.is_symlink()
        and not EXCLUDED_PARTS.intersection(path.relative_to(project_root).parts)
        and not path.name.startswith(".")
        and not path.name.endswith((".import", ".tmp", ".zip"))
        and path.resolve() != output.resolve()
    )
    directories = {
        parent
        for path in files
        for parent in path.relative_to(project_root).parents
        if parent != Path(".")
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        # Godot creates folders only for explicit directory entries, in archive order.
        for directory in sorted(directories, key=lambda path: (len(path.parts), path.as_posix())):
            archive.writestr(directory.as_posix() + "/", b"")
        for path in files:
            archive.write(path, path.relative_to(project_root).as_posix())
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP integrity check failed")
    print(f"Created {output}: {len(files)} files, {len(directories)} directories")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Destination ZIP path")
    args = parser.parse_args()
    package_project(PROJECT_ROOT, args.output)


if __name__ == "__main__":
    main()
