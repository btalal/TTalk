#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist
for MANIFEST in release-signatures/android-*.json; do
  MOBILE_TAG=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["release_tag"])' "$MANIFEST")
  # Keep previously verified releases untouched. In particular, publishing a new
  # version must not fail because an older unsigned build is no longer available.
  rm -f dist/existing-apk.sha256 dist/existing-release.json
  if gh release download "$MOBILE_TAG" --pattern ttalk-android.apk.sha256 --output dist/existing-apk.sha256; then
    if python3 -c 'import json,pathlib,sys; m=json.load(open(sys.argv[1])); p=pathlib.Path("dist/existing-apk.sha256").read_text().split(); sys.exit(0 if p and p[0] == m["signed_sha256"] else 1)' "$MANIFEST"; then
      gh release view "$MOBILE_TAG" --json name,isPrerelease,isDraft > dist/existing-release.json
      if python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); r=json.load(open("dist/existing-release.json")); tag=m["release_tag"]; stable=tag.startswith("android-v"); title="📱 Android — TTalk "+tag.removeprefix("android-v")+" · Version stable" if stable else "TTalk "+tag+" — Android signé et iPhone à signer"; sys.exit(0 if r["name"] == title and r["isPrerelease"] == (not stable) and not r["isDraft"] else 1)' "$MANIFEST"; then
        echo "Already published with expected checksum and release status: $MOBILE_TAG"
        continue
      fi
    fi
  fi
  python3 scripts/apply-android-signature.py "$MANIFEST" dist
  "$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --verbose --print-certs dist/ttalk-android.apk > dist/signature-verification.txt
  python3 -c 'import json,pathlib,sys; m=json.load(open(sys.argv[1])); p=pathlib.Path("dist/signature-verification.txt").read_text(); assert "Number of signers: 1" in p and "Verified using v2 scheme (APK Signature Scheme v2): true" in p and "certificate SHA-256 digest: "+m["certificate_sha256"] in p; print(p)' "$MANIFEST"
  MOBILE_TAG=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["release_tag"])' "$MANIFEST")
  gh release upload "$MOBILE_TAG" dist/ttalk-android.apk dist/ttalk-android.apk.sha256 --clobber
  NOTES_FILE=$(python3 -c 'import json,sys; print("release-signatures/"+json.load(open(sys.argv[1]))["notes_file"])' "$MANIFEST")
  if [[ "$MOBILE_TAG" == android-v* ]]; then
    gh release edit "$MOBILE_TAG" --title "📱 Android — TTalk ${MOBILE_TAG#android-v} · Version stable" --notes-file "$NOTES_FILE" --prerelease=false --latest=false
  else
    gh release edit "$MOBILE_TAG" --title "TTalk $MOBILE_TAG — Android signé et iPhone à signer" --notes-file "$NOTES_FILE" --prerelease --latest=false
  fi
done
