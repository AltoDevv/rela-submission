import tempfile
import unittest
import zipfile
from pathlib import Path

from package_submission import allowed_path, create_archive


class SubmissionPackageTest(unittest.TestCase):
    def test_source_and_example_config_are_included(self):
        for name in ['app/lib/main.dart', 'README.md', 'app/env.example.json',
                     'firebase/google-services.example.json', 'supabase/migrations/001.sql']:
            self.assertTrue(allowed_path(Path(name)), name)

    def test_private_files_are_excluded_even_if_tracked(self):
        for name in ['.env.local', '.env', 'app/env.json', 'firebase/service-account.json',
                     'firebase/service-account-copy.json', 'app/android/key.properties',
                     'app/android/local.properties', 'upload.jks', 'signing.keystore',
                     '.git/config', 'app/build/app.apk', 'dist/source.zip',
                     'docs/screenshots-relawan/01.png', 'progress.md',
                     'firebase/google-services.json', 'app/android/app/google-services.json',
                     'app/lib/firebase_options.dart']:
            self.assertFalse(allowed_path(Path(name)), name)

    def test_zip_contains_source_but_no_private_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'app/lib').mkdir(parents=True)
            (root / 'app/lib/main.dart').write_text('void main() {}')
            (root / 'app/env.json').write_text('{"private": "do not share"}')
            output = root / 'result.zip'
            create_archive(root, [Path('app/lib/main.dart'), Path('app/env.json')], output)
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.namelist(), ['ReLa/app/lib/main.dart'])

    def test_known_secret_in_source_blocks_packaging(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'README.md').write_text('Accidentally included: private-token-for-test')
            output = root / 'result.zip'
            with self.assertRaises(ValueError):
                create_archive(root, [Path('README.md')], output, secrets={'private-token-for-test'})
            self.assertFalse(output.exists())

    def test_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'private.txt').write_text('private')
            (root / 'README.md').symlink_to(root / 'private.txt')
            with self.assertRaises(ValueError):
                create_archive(root, [Path('README.md')], root / 'result.zip')

    def test_parent_path_is_rejected(self):
        self.assertFalse(allowed_path(Path('../secret.txt')))

    def test_unknown_google_api_key_blocks_packaging(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'README.md').write_text('key = ' + 'AIza' + 'x' * 35)
            output = root / 'result.zip'
            with self.assertRaises(ValueError):
                create_archive(root, [Path('README.md')], output, secrets=set())
            self.assertFalse(output.exists())

    def test_firebase_config_is_excluded_even_if_explicitly_listed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'firebase').mkdir()
            (root / 'firebase/google-services.json').write_text('{"client": "local only"}')
            (root / 'firebase/google-services.example.json').write_text('{"api_key": "YOUR_FIREBASE_API_KEY"}')
            output = root / 'result.zip'
            create_archive(root, [Path('firebase/google-services.json'), Path('firebase/google-services.example.json')], output)
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.namelist(), ['ReLa/firebase/google-services.example.json'])

    def test_executable_mode_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / 'run.sh'
            script.write_text('#!/bin/sh\necho demo\n')
            script.chmod(0o755)
            output = root / 'result.zip'
            create_archive(root, [Path('run.sh')], output)
            with zipfile.ZipFile(output) as archive:
                mode = archive.getinfo('ReLa/run.sh').external_attr >> 16
                self.assertTrue(mode & 0o111)


if __name__ == '__main__':
    unittest.main()
