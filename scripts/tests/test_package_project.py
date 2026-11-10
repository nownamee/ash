import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "package_project", Path(__file__).resolve().parents[1] / "package-project.py"
)
packager = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packager)


class PackageProjectTests(unittest.TestCase):
    def test_godot_ordered_extraction_and_project_only_layout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = root / "game"
            expected = {
                "project.godot": b"config_version=5\n",
                "menu.gd": b"extends Control\n",
                "fonts/example.ttf": b"font bytes",
                "icons/nested/example.svg": b"<svg/>",
            }
            excluded = [
                ".godot/imported/cache.ctex", "icons/example.svg.import",
                "tests/local_test.gd", ".private", "old.zip", "scratch.tmp",
            ]
            for name, content in {**expected, **dict.fromkeys(excluded, b"excluded")}.items():
                target = project / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
            (root / "96.zip").write_bytes(b"original archive outside project")
            output = root / "game.zip"
            packager.package_project(project, output)
            destination = root / "installed"
            destination.mkdir()
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(
                    {entry.filename for entry in archive.infolist() if not entry.is_dir()},
                    set(expected),
                )
                self.assertIn("project.godot", archive.namelist())
                # Match Godot's importer: mkdir for directory entries, never file parents.
                for entry in archive.infolist():
                    name = Path(entry.filename)
                    self.assertFalse(name.is_absolute())
                    self.assertNotIn("..", name.parts)
                    target = destination / name
                    if entry.is_dir():
                        target.mkdir()
                    else:
                        target.write_bytes(archive.read(entry))
                self.assertIsNone(archive.testzip())
            for name, content in expected.items():
                self.assertEqual((destination / name).read_bytes(), content)

    def test_requires_project_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(ValueError, "Missing project.godot"):
                packager.package_project(root, root / "bad.zip")


if __name__ == "__main__":
    unittest.main()
