import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from source_provenance import digest, source_revision, verify_archive
from build_local_macos import apple_build_tools, output_directory

COMMIT = '1' * 40


class SourceBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.repo = self.directory / 'source'
        self.repo.mkdir()
        self.files = {'project.godot': b'config/version="6.1.0-rc.2"',
                      'tools/export_macos.py': b'# exporter', 'updater/main.go': b'package main'}
        for name, data in self.files.items():
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        self.archive = self.directory / 'source.zip'
        self.write_archive()

    def write_archive(self, extra=None):
        with zipfile.ZipFile(self.archive, 'w') as z:
            for name, data in self.files.items():
                z.writestr('Aisora-' + COMMIT + '/' + name, data)
            if extra:
                z.writestr(extra[0], extra[1])
        self.sha = digest(self.archive)

    def proof(self):
        return verify_archive(self.repo, self.archive, self.sha, COMMIT)

    def install_proof(self):
        data = self.proof()
        (self.repo / '.local').mkdir(exist_ok=True)
        (self.repo / '.local/source-provenance.json').write_text(json.dumps(data))

    def test_archive_build_never_calls_git_and_rechecks_sources(self):
        self.install_proof()
        with patch('source_provenance.subprocess.check_output', side_effect=AssertionError('git must not run')):
            self.assertEqual(source_revision(self.repo, include_dirty=True), COMMIT)
            (self.repo / 'project.godot').write_text('tampered')
            with self.assertRaisesRegex(ValueError, 'Source differs'):
                source_revision(self.repo)

    def test_wrong_archive_hash_stops_before_build_marker(self):
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            verify_archive(self.repo, self.archive, '0' * 64, COMMIT)
        self.assertFalse((self.repo / '.local').exists())

    def test_unexpected_runtime_input_rejected(self):
        (self.repo / 'injected.gd').write_text('extends Node')
        with self.assertRaisesRegex(ValueError, 'Unexpected source file'):
            self.proof()

    def test_traversal_case_collision_and_wrong_root_rejected(self):
        for name in ['Aisora-' + COMMIT + '/../escape', 'Aisora-' + COMMIT + '/PROJECT.GODOT', 'Other/project.godot']:
            with self.subTest(name=name):
                self.write_archive((name, b'bad'))
                with self.assertRaises(ValueError):
                    self.proof()

    def test_source_symlink_and_generated_directory_symlink_rejected(self):
        for name in ['tools/export_macos.py', '.local']:
            with self.subTest(name=name):
                target = self.repo / name
                if target.exists():
                    target.unlink()
                target.symlink_to(self.directory, target_is_directory=True)
                with self.assertRaises(ValueError):
                    self.proof()
                target.unlink()
                if name in self.files:
                    target.write_bytes(self.files[name])

    def test_generated_build_outputs_allowed_but_not_new_source(self):
        for folder in ['.local', '.godot', 'exports', 'tools/__pycache__']:
            target = self.repo / folder
            target.mkdir(parents=True, exist_ok=True)
            (target / 'generated').write_text('output')
        self.assertEqual(self.proof()['source_commit'], COMMIT)
        (self.repo / 'updater/injected.go').write_text('package main')
        with self.assertRaisesRegex(ValueError, 'Unexpected source file'):
            self.proof()

    def test_git_checkout_keeps_previous_revision_and_dirty_semantics(self):
        (self.repo / '.git').mkdir()
        with patch('source_provenance.subprocess.check_output', side_effect=[COMMIT + '\n', b' M file']):
            self.assertEqual(source_revision(self.repo, include_dirty=True), COMMIT + '-dirty')
        with patch('source_provenance.subprocess.check_output', return_value=COMMIT + '\n') as call:
            self.assertEqual(source_revision(self.repo), COMMIT)
            self.assertEqual(call.call_count, 1)

    def test_archive_export_without_verification_marker_fails(self):
        with self.assertRaisesRegex(ValueError, 'checksum'):
            source_revision(self.repo)

    def test_output_cannot_replace_installed_or_existing_app(self):
        exports = self.repo / 'exports'
        exports.mkdir()
        existing = exports / 'working'
        existing.mkdir()
        for destination in [existing, exports, self.directory / 'Applications/Aisora.app']:
            with self.assertRaises(ValueError):
                output_directory(self.repo, destination)
        self.assertEqual(output_directory(self.repo, exports / 'new'), exports / 'new')
        self.assertTrue(existing.is_dir())

    def test_exports_symlink_cannot_redirect_build_to_installation(self):
        (self.repo / 'exports').symlink_to(self.directory, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            output_directory(self.repo, self.repo / 'exports/new')

    def test_missing_apple_tools_query_stops_without_installing_them(self):
        result = subprocess.CompletedProcess([], 2, '', 'no active developer directory')
        with patch('build_local_macos.subprocess.run', return_value=result) as call:
            with self.assertRaisesRegex(ValueError, 'Command Line Tools'):
                apple_build_tools()
            self.assertEqual(call.call_args.args[0], ['/usr/bin/xcode-select', '--print-path'])

    def test_installed_apple_tools_query_does_not_change_selection(self):
        result = subprocess.CompletedProcess([], 0, str(self.directory) + '\n', '')
        with patch('build_local_macos.subprocess.run', return_value=result) as call:
            apple_build_tools()
            self.assertEqual(call.call_count, 1)
            self.assertEqual(call.call_args.args[0], ['/usr/bin/xcode-select', '--print-path'])

    @unittest.skipIf(sys.platform == 'darwin', 'Linux guard check')
    def test_non_macos_guard_does_not_create_output(self):
        target = self.directory / 'never-created'
        result = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / 'tools/build_local_macos.py'),
                                 '--archive', str(self.archive), '--archive-sha256', self.sha, '--source-commit', COMMIT,
                                 '--output', str(target)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Intel Mac', result.stderr)
        self.assertFalse(target.exists())


if __name__ == '__main__':
    unittest.main()
