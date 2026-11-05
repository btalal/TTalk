#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist
for MANIFEST in release-signatures/android-*.json; do
  MOBILE_TAG=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["release_tag"])' "$MANIFEST")
  NOTES_FILE=$(python3 -c 'import json,sys; print("release-signatures/"+json.load(open(sys.argv[1]))["notes_file"])' "$MANIFEST")
  case "$MOBILE_TAG" in
    android-v0.5.0) RELEASE_TITLE='TTalk 0.5.0 — Android · Stable historique'; RELEASE_STATUS='--prerelease=false' ;;
    android-v*) RELEASE_TITLE="TTalk ${MOBILE_TAG#android-v} — Android · Stable"; RELEASE_STATUS='--prerelease=false' ;;
    mobile-v0.5.0-preview.11) RELEASE_TITLE='TTalk 0.5.0 Preview 11 — Android et iPhone'; RELEASE_STATUS='--prerelease' ;;
    *) RELEASE_TITLE="TTalk $MOBILE_TAG — Android et iPhone · Préversion"; RELEASE_STATUS='--prerelease' ;;
  esac
  # Keep previously verified releases untouched. In particular, publishing a new
  # version must not fail because an older unsigned build is no longer available.
  rm -f dist/existing-apk.sha256
  if gh release download "$MOBILE_TAG" --pattern ttalk-android.apk.sha256 --output dist/existing-apk.sha256; then
    if python3 -c 'import json,pathlib,sys; m=json.load(open(sys.argv[1])); p=pathlib.Path("dist/existing-apk.sha256").read_text().split(); sys.exit(0 if p and p[0] == m["signed_sha256"] else 1)' "$MANIFEST"; then
      gh release edit "$MOBILE_TAG" --title "$RELEASE_TITLE" --notes-file "$NOTES_FILE" "$RELEASE_STATUS" --latest=false
      echo "Already published with expected checksum; updated release presentation: $MOBILE_TAG"
      continue
    fi
  fi
  python3 scripts/apply-android-signature.py "$MANIFEST" dist
  "$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --verbose --print-certs dist/ttalk-android.apk > dist/signature-verification.txt
  python3 -c 'import json,pathlib,sys; m=json.load(open(sys.argv[1])); p=pathlib.Path("dist/signature-verification.txt").read_text(); assert "Number of signers: 1" in p and "Verified using v2 scheme (APK Signature Scheme v2): true" in p and "certificate SHA-256 digest: "+m["certificate_sha256"] in p; print(p)' "$MANIFEST"
  gh release upload "$MOBILE_TAG" dist/ttalk-android.apk dist/ttalk-android.apk.sha256 --clobber
  gh release edit "$MOBILE_TAG" --title "$RELEASE_TITLE" --notes-file "$NOTES_FILE" "$RELEASE_STATUS" --latest=false
done
