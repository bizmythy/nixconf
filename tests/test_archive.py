from __future__ import annotations

import importlib.util
import io
import shutil
import stat
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

from click.testing import CliRunner


ROOT = Path(__file__).resolve().parents[1]


def load_archive_module():
    module_path = ROOT / "home/programs/archive/main.py"
    spec = importlib.util.spec_from_file_location("archive_main", module_path)
    if spec is None or spec.loader is None:
        raise AssertionError("unable to load archive module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class ArchiveCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_archive_module()
        self.runner = CliRunner()

    def create_sample_tree(self, root: Path) -> Path:
        source = root / "sample"
        source.mkdir()
        (source / "nested").mkdir()
        (source / "nested" / "deep").mkdir()
        (source / "hello.txt").write_text("hello world\n", encoding="utf-8")
        script = source / "nested" / "run.sh"
        script.write_text("#!/bin/sh\necho hi\n", encoding="utf-8")
        script.chmod(0o755)
        (source / "nested" / "deep" / "note.txt").write_text(
            "deep file\n", encoding="utf-8"
        )
        (source / "empty").mkdir()
        (source / "link.txt").symlink_to("hello.txt")
        return source

    def assert_extracted_tree(self, extracted: Path) -> None:
        self.assertEqual(
            (extracted / "hello.txt").read_text(encoding="utf-8"),
            "hello world\n",
        )
        self.assertEqual(
            (extracted / "nested" / "deep" / "note.txt").read_text(
                encoding="utf-8"
            ),
            "deep file\n",
        )
        self.assertTrue((extracted / "empty").is_dir())
        self.assertTrue((extracted / "link.txt").is_symlink())
        self.assertEqual(os_readlink(extracted / "link.txt"), "hello.txt")
        self.assertTrue(
            (extracted / "nested" / "run.sh").stat().st_mode & stat.S_IXUSR
        )
        self.assertFalse((extracted / "sample").exists())

    def test_archive_type_helpers(self) -> None:
        archive_type = self.module.ArchiveType

        self.assertIs(
            archive_type.from_path(Path("example.zip")),
            archive_type.ZIP,
        )
        self.assertIs(
            archive_type.from_path(Path("example.tar.gz")),
            archive_type.TAR_GZ,
        )
        self.assertIs(
            archive_type.from_path(Path("example.tar.zst")),
            archive_type.TAR_ZST,
        )
        self.assertEqual(
            archive_type.strip_archive_suffix("example.tar.zst"), "example"
        )
        self.assertIs(
            archive_type.from_extension_shorthand(".tar.gz"),
            archive_type.TAR_GZ,
        )

        with self.assertRaisesRegex(
            Exception, "unsupported archive extension"
        ):
            archive_type.from_path(Path("example.tar"))

    def test_default_compress_target_uses_tar_zst(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            source = Path(tmp_dir) / "sample"
            source.mkdir()
            request = self.module.resolve_compression_request(
                str(source), None, False
            )

        self.assertEqual(request.archive_type, self.module.ArchiveType.TAR_ZST)
        self.assertEqual(request.archive_path.name, "sample.tar.zst")

    def test_compress_extension_shorthand_resolves_from_directory_name(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            source = Path(tmp_dir) / "sample"
            source.mkdir()
            request = self.module.resolve_compression_request(
                str(source), ".zip", False
            )

        self.assertEqual(request.archive_type, self.module.ArchiveType.ZIP)
        self.assertEqual(request.archive_path.name, "sample.zip")

    def test_extract_default_output_directory_is_inferred(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            archive = Path(tmp_dir) / "example.tar.gz"
            archive.write_bytes(b"placeholder")
            request = self.module.resolve_extraction_request(
                str(archive), None, False
            )

        self.assertEqual(request.output_directory.name, "example")

    def test_round_trip_for_each_supported_format(self) -> None:
        formats = [
            self.module.ArchiveType.ZIP,
            self.module.ArchiveType.TAR_GZ,
            self.module.ArchiveType.TAR_ZST,
        ]

        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            source = self.create_sample_tree(tmp_path)

            for archive_type in formats:
                archive_path = tmp_path / f"sample{archive_type.extension}"
                result = self.runner.invoke(
                    self.module.cli,
                    ["compress", str(source), str(archive_path)],
                )
                self.assertEqual(result.exit_code, 0, result.output)
                self.assertTrue(archive_path.exists())

                extract_root = tmp_path / f"extract-{archive_type.label}"
                result = self.runner.invoke(
                    self.module.cli,
                    [
                        "extract",
                        str(archive_path),
                        str(extract_root),
                    ],
                )
                self.assertEqual(result.exit_code, 0, result.output)
                self.assert_extracted_tree(extract_root)
                shutil.rmtree(extract_root)

    def test_compress_fails_when_archive_exists_without_force(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            source = self.create_sample_tree(tmp_path)
            archive_path = tmp_path / "sample.zip"
            archive_path.write_bytes(b"existing")

            result = self.runner.invoke(
                self.module.cli,
                ["compress", str(source), str(archive_path)],
            )

        self.assertNotEqual(result.exit_code, 0)
        self.assertIn("archive already exists", result.output)

    def test_compress_force_replaces_existing_archive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            source = self.create_sample_tree(tmp_path)
            archive_path = tmp_path / "sample.zip"
            archive_path.write_bytes(b"existing")

            result = self.runner.invoke(
                self.module.cli,
                ["compress", "--force", str(source), str(archive_path)],
            )

            self.assertEqual(result.exit_code, 0, result.output)
            self.assertGreater(archive_path.stat().st_size, len(b"existing"))

    def test_extract_fails_when_output_directory_exists_without_force(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            source = self.create_sample_tree(tmp_path)
            archive_path = tmp_path / "sample.zip"
            compress_result = self.runner.invoke(
                self.module.cli,
                ["compress", str(source), str(archive_path)],
            )
            self.assertEqual(
                compress_result.exit_code, 0, compress_result.output
            )

            output_directory = tmp_path / "existing-output"
            output_directory.mkdir()
            result = self.runner.invoke(
                self.module.cli,
                ["extract", str(archive_path), str(output_directory)],
            )

        self.assertNotEqual(result.exit_code, 0)
        self.assertIn("output directory already exists", result.output)

    def test_extract_force_replaces_existing_output_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            source = self.create_sample_tree(tmp_path)
            archive_path = tmp_path / "sample.tar.zst"
            compress_result = self.runner.invoke(
                self.module.cli,
                ["compress", str(source), str(archive_path)],
            )
            self.assertEqual(
                compress_result.exit_code, 0, compress_result.output
            )

            output_directory = tmp_path / "restored"
            output_directory.mkdir()
            (output_directory / "stale.txt").write_text(
                "stale\n", encoding="utf-8"
            )

            result = self.runner.invoke(
                self.module.cli,
                [
                    "extract",
                    "--force",
                    str(archive_path),
                    str(output_directory),
                ],
            )

            self.assertEqual(result.exit_code, 0, result.output)
            self.assertFalse((output_directory / "stale.txt").exists())
            self.assert_extracted_tree(output_directory)

    def test_extract_rejects_zip_path_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            archive_path = tmp_path / "unsafe.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("../evil.txt", "bad")

            result = self.runner.invoke(
                self.module.cli,
                ["extract", str(archive_path), str(tmp_path / "out")],
            )

        self.assertNotEqual(result.exit_code, 0)
        self.assertIn("must not escape the output directory", result.output)

    def test_extract_rejects_tar_path_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            archive_path = tmp_path / "unsafe.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                data = b"bad"
                info = tarfile.TarInfo("../evil.txt")
                info.size = len(data)
                archive.addfile(info, io.BytesIO(data))

            result = self.runner.invoke(
                self.module.cli,
                ["extract", str(archive_path), str(tmp_path / "out")],
            )

        self.assertNotEqual(result.exit_code, 0)
        self.assertIn("must not escape the output directory", result.output)

    def test_extract_rejects_unsafe_symlink_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            archive_path = tmp_path / "unsafe.tar.zst"
            writer = io.BytesIO()
            compressor = self.module.zstandard.ZstdCompressor()
            with compressor.stream_writer(writer, closefd=False) as compressed:
                with tarfile.open(fileobj=compressed, mode="w|") as archive:
                    info = tarfile.TarInfo("link.txt")
                    info.type = tarfile.SYMTYPE
                    info.linkname = "../escape.txt"
                    archive.addfile(info)
            archive_path.write_bytes(writer.getvalue())

            result = self.runner.invoke(
                self.module.cli,
                ["extract", str(archive_path), str(tmp_path / "out")],
            )

        self.assertNotEqual(result.exit_code, 0)
        self.assertIn("symlink target", result.output)

    def test_help_lists_subcommands(self) -> None:
        result = self.runner.invoke(self.module.cli, ["--help"])

        self.assertEqual(result.exit_code, 0, result.output)
        self.assertIn("compress", result.output)
        self.assertIn("extract", result.output)


def os_readlink(path: Path) -> str:
    return str(path.readlink())


if __name__ == "__main__":
    unittest.main()
