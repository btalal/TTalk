#!/usr/bin/env python3
"""Prepare a disposable checkout for side-by-side personal testing, never release."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARKER = ROOT / '.personal-test-build'
if MARKER.exists():
    raise SystemExit('This checkout is already configured for personal tests.')

def replace(path, old, new):
    p = ROOT / path
    source = p.read_text()
    if old not in source:
        raise SystemExit(f'Expected configuration missing: {path}: {old}')
    p.write_text(source.replace(old, new))

replace('android/app/build.gradle.kts', 'applicationId = "com.talal.ttalk"',
        'applicationId = "com.talal.ttalk.preview"')
replace('android/app/src/main/AndroidManifest.xml', 'android:label="TTalk"',
        'android:label="TTalk Test"')
replace('ios/Runner.xcodeproj/project.pbxproj', 'com.talal.ttalk', 'com.talal.ttalk.preview')
replace('ios/Runner/Info.plist', '<string>TTalk</string>', '<string>TTalk Test</string>')
replace('macos/Runner/Configs/AppInfo.xcconfig', 'PRODUCT_NAME = ttalk', 'PRODUCT_NAME = TTalk Test')
replace('macos/Runner/Configs/AppInfo.xcconfig', 'com.talal.ttalk', 'com.talal.ttalk.preview')
replace('windows/runner/Runner.rc', 'VALUE "ProductName", "ttalk"',
        'VALUE "ProductName", "TTalk Test"')
replace('windows/runner/Runner.rc', 'VALUE "FileDescription", "ttalk"',
        'VALUE "FileDescription", "TTalk Test"')
replace('windows/runner/main.cpp', 'com.talal.ttalk', 'com.talal.ttalk.preview')
replace('lib/main.dart', "title: 'TTalk'", "title: 'TTalk Test'")
replace('lib/ui/home_screen.dart', ": 'TTalk';", ": 'TTalk Test';")
MARKER.write_text('Personal test identifiers and Windows storage namespace. Not a stable release.\n')
print('Prepared TTalk Test: independent app IDs, Windows storage and process mutex.')
