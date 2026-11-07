"""Reproduce an offline-signed public APK without giving CI its private key."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


manifest_path = Path(sys.argv[1]).resolve()
manifest = json.loads(manifest_path.read_text())
tag = manifest['release_tag']
if not re.fullmatch(r'(?:v\d+\.\d+\.\d+-android|v\d+\.\d+\.\d+-preview\.\d+-mobile|mobile-v\d+\.\d+\.\d+-preview\.\d+|android-v\d+\.\d+\.\d+)', tag):
    raise ValueError('Unexpected mobile release tag')
notes = (manifest_path.parent / manifest['notes_file']).resolve()
if notes.parent != manifest_path.parent or notes.suffix != '.md' or not notes.is_file():
    raise ValueError('Invalid release notes file')
expected_url = f'https://github.com/btalal/TTalk/releases/download/{tag}/ttalk-android-unsigned.apk'
if manifest['unsigned_url'] != expected_url:
    raise ValueError('Unexpected unsigned APK source')
patch = (manifest_path.parent / manifest['patch_file']).resolve()
if patch.parent != manifest_path.parent or digest(patch) != manifest['patch_sha256']:
    raise ValueError('Invalid public signature patch')
output = Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=True)
signed = output / 'ttalk-android.apk'
with tempfile.TemporaryDirectory(prefix='ttalk-apk-') as temporary:
    original = Path(temporary) / 'unsigned.apk'
    with urllib.request.urlopen(expected_url, timeout=120) as response, original.open('wb') as target:
        shutil.copyfileobj(response, target)
    if digest(original) != manifest['unsigned_sha256']:
        raise ValueError('Unsigned APK checksum mismatch')
    subprocess.run(['bspatch', str(original), str(signed), str(patch)], check=True)
    if digest(signed) != manifest['signed_sha256']:
        signed.unlink()
        raise ValueError('Signed APK checksum mismatch')
(output / 'ttalk-android.apk.sha256').write_text(f"{digest(signed)}  {signed.name}\n")
print(f'Verified signed APK: {digest(signed)}')
