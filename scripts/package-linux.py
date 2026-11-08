#!/usr/bin/env python3
"""Package the native x86_64 Flutter bundle; run on Linux, never as a release signer."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def validate_bundle(bundle):
    for name in ['ttalk', 'lib/libflutter_linux_gtk.so', 'lib/libapp.so', 'data/icudtl.dat']:
        p = bundle / name
        if not p.is_file():
            raise ValueError(f'Missing bundle member: {name}')
    elf = (bundle / 'ttalk').read_bytes()[:20]
    if elf[:6] != b'\x7fELF\x02\x01' or struct.unpack('<H', elf[18:20])[0] != 62:
        raise ValueError('Expected a Linux x86_64 executable')
    if not os.access(bundle / 'ttalk', os.X_OK):
        raise ValueError('Executable permission missing')
    for p in bundle.rglob('*'):
        if p.is_symlink() and not p.resolve().is_relative_to(bundle.resolve()):
            raise ValueError(f'Bundle link escapes its root: {p}')
    missing = run('ldd', bundle / 'ttalk', capture_output=True, text=True).stdout
    if 'not found' in missing:
        raise ValueError(missing)


def stage(bundle, root):
    target = root / 'usr/lib/ttalk'
    target.parent.mkdir(parents=True)
    shutil.copytree(bundle, target, symlinks=True)
    (root / 'usr/bin').mkdir(parents=True)
    (root / 'usr/bin/ttalk').symlink_to('../lib/ttalk/ttalk')
    for source, destination in [
        ('packaging/linux/com.talal.ttalk.desktop', 'usr/share/applications/com.talal.ttalk.desktop'),
        ('assets/branding/ttalk.png', 'usr/share/pixmaps/com.talal.ttalk.png'),
        ('LICENSE', 'usr/share/doc/ttalk/LICENSE'),
        ('NOTICE', 'usr/share/doc/ttalk/NOTICE'),
        ('assets/fonts/Inter-LICENSE.txt', 'usr/share/doc/ttalk/Inter-LICENSE.txt'),
        ('docs/LINUX_INSTALL.md', 'usr/share/doc/ttalk/LINUX_INSTALL.md'),
        ('docs/LINUX_VALIDATION.md', 'usr/share/doc/ttalk/LINUX_VALIDATION.md'),
    ]:
        p = root / destination
        p.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / source, p)
    # Flutter installs plugin libraries as files, retaining their build RPATH.
    # Replace those paths with bundle-relative lookup before either packaging format.
    for p in target.rglob('*'):
        if not p.is_file() or p.read_bytes()[:4] != b'\x7fELF':
            continue
        result = subprocess.run(['patchelf', '--print-rpath', str(p)], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            run('patchelf', '--set-rpath', '$ORIGIN/lib' if p == target / 'ttalk' else '$ORIGIN', p)
            expected = '$ORIGIN/lib' if p == target / 'ttalk' else '$ORIGIN'
            if run('patchelf', '--print-rpath', p, capture_output=True, text=True).stdout.strip() != expected:
                raise ValueError(f'Unsafe runtime path: {p}')
    for p in root.rglob('*'):
        if not p.is_symlink():
            p.chmod(0o755 if p.is_dir() or p == target / 'ttalk' else 0o644)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('format', choices=['deb', 'rpm'])
    parser.add_argument('--bundle', default='build/linux/x64/release/bundle')
    parser.add_argument('--output', default='dist/linux')
    args = parser.parse_args()
    os.chdir(ROOT)
    version = re.search(r'^version: (\d+\.\d+\.\d+)\+\d+$', (ROOT / 'pubspec.yaml').read_text(), re.M)
    if not version:
        raise ValueError('A stable semantic version and build number are required')
    version = version[1]
    revision = (ROOT / 'packaging/linux/revision').read_text().strip()
    if not revision.isdigit() or int(revision) < 1:
        raise ValueError('Invalid package revision')
    bundle, output = Path(args.bundle).resolve(), Path(args.output).resolve()
    validate_bundle(bundle)
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ttalk-package-') as temporary:
        tmp = Path(temporary)
        payload = tmp / 'payload'
        stage(bundle, payload)
        if args.format == 'deb':
            if run('dpkg', '--print-architecture', capture_output=True, text=True).stdout.strip() != 'amd64':
                raise ValueError('Build this DEB on an amd64 distribution')
            work = tmp / 'debian-build'
            (work / 'debian').mkdir(parents=True)
            (work / 'debian/control').write_text('Source: ttalk\nSection: net\nPriority: optional\nMaintainer: TTalk contributors <noreply@github.com>\n\nPackage: ttalk\nArchitecture: amd64\nDescription: Encrypted messenger\n')
            binaries = [p for p in (payload / 'usr/lib/ttalk').rglob('*') if p.is_file() and p.read_bytes()[:4] == b'\x7fELF']
            dependencies = run('dpkg-shlibdeps', '--ignore-missing-info', '-O', '-l' + str(payload / 'usr/lib/ttalk/lib'), *['-e' + str(p) for p in binaries], cwd=work, capture_output=True, text=True).stdout.strip().removeprefix('shlibs:Depends=')
            if not dependencies or 'libc6' not in dependencies:
                raise ValueError('Unable to compute Debian runtime dependencies')
            control = payload / 'DEBIAN'
            control.mkdir()
            size = sum(p.stat().st_size for p in payload.rglob('*') if p.is_file()) // 1024
            (control / 'control').write_text(f'Package: ttalk\nVersion: {version}-{revision}\nArchitecture: amd64\nMaintainer: TTalk contributors <noreply@github.com>\nSection: net\nPriority: optional\nHomepage: https://github.com/btalal/TTalk\nInstalled-Size: {size}\nDepends: {dependencies}, gnome-keyring, dbus-user-session, xdg-utils, xdg-desktop-portal, xdg-desktop-portal-gtk, fonts-noto-color-emoji\nDescription: Encrypted messenger with a relay of your choice\n Native Flutter application. Local vault requires an unlocked Secret Service keyring.\n')
            package = output / f'ttalk_{version}-{revision}_amd64.deb'
            run('dpkg-deb', '--root-owner-group', '--build', payload, package)
            run('dpkg-deb', '--info', package)
        else:
            top = tmp / 'rpmbuild'
            for directory in ['BUILD', 'BUILDROOT', 'RPMS', 'SOURCES', 'SPECS', 'SRPMS']:
                (top / directory).mkdir(parents=True)
            spec = top / 'SPECS/ttalk.spec'
            spec.write_text(f'''%global debug_package %{{nil}}
Name: ttalk
Version: {version}
Release: {revision}%{{?dist}}
Summary: Encrypted messenger with a relay of your choice
License: Apache-2.0
URL: https://github.com/btalal/TTalk
ExclusiveArch: x86_64
Requires: gtk3, libsecret, gnome-keyring, dbus, xdg-utils, xdg-desktop-portal, xdg-desktop-portal-gtk, google-noto-color-emoji-fonts

%description
Native Flutter application. Local vault requires an unlocked Secret Service keyring.

%prep
%build
%install
mkdir -p "%{{buildroot}}"
cp -a "{payload}/." "%{{buildroot}}/"

%files
/usr/bin/ttalk
/usr/lib/ttalk
/usr/share/applications/com.talal.ttalk.desktop
/usr/share/pixmaps/com.talal.ttalk.png
%doc /usr/share/doc/ttalk/LINUX_INSTALL.md
%doc /usr/share/doc/ttalk/LINUX_VALIDATION.md
%license /usr/share/doc/ttalk/LICENSE
%license /usr/share/doc/ttalk/NOTICE
%license /usr/share/doc/ttalk/Inter-LICENSE.txt

%changelog
* Sun Nov 08 2026 TTalk contributors <noreply@github.com> - {version}-{revision}
- Initial Linux packages.
''')
            run('rpmbuild', '-bb', '--define', '_topdir ' + str(top), spec)
            built = list((top / 'RPMS/x86_64').glob('ttalk-*.rpm'))
            if len(built) != 1:
                raise ValueError('Expected one RPM')
            package = output / built[0].name
            shutil.copyfile(built[0], package)
            run('rpm', '-qpi', package)
        (output / (package.name + '.sha256')).write_text(hashlib.sha256(package.read_bytes()).hexdigest() + '  ' + package.name + '\n')
        print(package)


if __name__ == '__main__':
    main()
