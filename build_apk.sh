#!/usr/bin/env bash
# Builds the RedDrop APK on a computer that has Flutter + Android SDK installed.
# Usage (from the reddrop folder):  bash build_apk.sh
set -e

flutter create --platforms=android --org com.reddrop --project-name reddrop build_app
rm -rf build_app/lib build_app/test
cp -r lib build_app/lib
cp pubspec.yaml build_app/pubspec.yaml
sed -i.bak 's/android:label="[^"]*"/android:label="RedDrop"/' build_app/android/app/src/main/AndroidManifest.xml

cd build_app
flutter pub get
flutter build apk --release

echo
echo "Done. Your APK is here:"
echo "$(pwd)/build/app/outputs/flutter-apk/app-release.apk"
