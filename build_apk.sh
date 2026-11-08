#!/usr/bin/env bash
# Builds the RedDrop APK on a computer that has Flutter + Android SDK installed.
# Usage (from the reddrop folder):  bash build_apk.sh
set -e

flutter create --platforms=android --org com.reddrop --project-name reddrop build_app
rm -rf build_app/lib build_app/test
cp -r lib build_app/lib
cp pubspec.yaml build_app/pubspec.yaml

M=build_app/android/app/src/main/AndroidManifest.xml
sed -i.bak 's/android:label="[^"]*"/android:label="RedDrop"/' $M
sed -i.bak 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' $M
if [ -f build_app/android/app/build.gradle.kts ]; then
  sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = 23/' build_app/android/app/build.gradle.kts
fi
if [ -f build_app/android/app/build.gradle ]; then
  sed -i.bak 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' build_app/android/app/build.gradle
fi

cd build_app
flutter pub get
flutter build apk --release

echo
echo "Done. Your APK is here:"
echo "$(pwd)/build/app/outputs/flutter-apk/app-release.apk"
