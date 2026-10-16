"""Prepare a source snapshot for submission without committing or uploading anything."""
import argparse
import base64
import json
import re
import subprocess
import zipfile
from pathlib import Path

BLOCKED_PARTS = {'.git', '.aws', '.codex', '.agents', '.ssh', '.idea', '.gradle',
                 '.dart_tool', '__pycache__', 'node_modules', 'build', 'dist', '.venv', 'venv'}
PRIVATE_SUFFIXES = {'.jks', '.keystore', '.pem', '.p12', '.key', '.pyc'}


def allowed_path(path):
    if path.is_absolute() or '..' in path.parts or set(path.parts) & BLOCKED_PARTS:
        return False
    name = path.name.lower()
    if name in {'.env', '.env.local', 'env.json', 'key.properties', 'local.properties', 'progress.md',
                'google-services.json', 'firebase_options.dart'}:
        return False
    if name.startswith('.env.') and not name.endswith('.example'):
        return False
    if name.startswith('service-account') or path.suffix.lower() in PRIVATE_SUFFIXES:
        return False
    return not (len(path.parts) >= 2 and path.parts[:2] == ('docs', 'screenshots-relawan'))


def private_values(root):
    values = set()
    env = root / '.env.local'
    if env.exists():
        for line in env.read_text().splitlines():
            if '=' not in line or line.lstrip().startswith('#'):
                continue
            key, value = line.split('=', 1)
            if re.search(r'SERVICE_ROLE|GEMINI.*KEY|SECRET|TOKEN|PASSWORD', key, re.I):
                value = value.strip().strip('\"\'')
                if len(value) > 12:
                    values.add(value)
    account = root / 'firebase/service-account.json'
    if account.exists():
        key = json.loads(account.read_text()).get('private_key', '')
        if key:
            values.update({key, key.replace('\n', '\\n')})
    return values


def contains_private_material(text, secrets):
    if re.search(r'AIza[0-9A-Za-z_-]{35}', text):
        return True
    if any(secret in text for secret in secrets):
        return True
    if re.search(r'-----BEGIN (?:RSA )?PRIVATE KEY-----(?:\s|\\n|[A-Za-z0-9+/=]){40,}-----END (?:RSA )?PRIVATE KEY-----', text):
        return True
    for token in re.findall(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', text):
        try:
            payload = token.split('.')[1]
            data = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            if data.get('role') == 'service_role':
                return True
        except (ValueError, UnicodeError):
            continue
    return False


def create_archive(root, paths, output, secrets=None):
    root = root.resolve()
    secrets = private_values(root) if secrets is None else secrets
    entries = []
    for relative in sorted(set(paths)):
        if not allowed_path(relative):
            continue
        file = root / relative
        if file.is_symlink() or not file.resolve().is_relative_to(root):
            raise ValueError(f'Tautan simbolik tidak dimasukkan: {relative}')
        if not file.is_file():
            continue
        content = file.read_bytes()
        if contains_private_material(content.decode('utf-8', errors='ignore'), secrets):
            raise ValueError(f'Berhenti: materi privat ditemukan dalam {relative}')
        entries.append((relative, content))
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for relative, content in entries:
            info = zipfile.ZipInfo('ReLa/' + relative.as_posix())
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (root / relative).stat().st_mode << 16
            archive.writestr(info, content)
    return len(entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('dist/submission/ReLa-source.zip'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    listed = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root)
    paths = [Path(p.decode()) for p in listed.split(b'\0') if p]
    count = create_archive(root, paths, args.output.resolve())
    print(f'Siap: {args.output} ({count} berkas; pemeriksaan materi privat lulus).')


if __name__ == '__main__':
    main()
