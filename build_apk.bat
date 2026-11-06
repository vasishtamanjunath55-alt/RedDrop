@echo off
REM Builds the RedDrop APK on Windows (needs Flutter + Android SDK installed).
REM Run from the reddrop folder:  build_apk.bat

call flutter create --platforms=android --org com.reddrop --project-name reddrop build_app
if errorlevel 1 goto fail

rmdir /s /q build_app\lib
rmdir /s /q build_app\test
xcopy /e /i /y lib build_app\lib
copy /y pubspec.yaml build_app\pubspec.yaml

powershell -Command "(Get-Content build_app\android\app\src\main\AndroidManifest.xml) -replace 'android:label=\"[^\"]*\"','android:label=\"RedDrop\"' | Set-Content build_app\android\app\src\main\AndroidManifest.xml"

cd build_app
call flutter pub get
if errorlevel 1 goto fail
call flutter build apk --release
if errorlevel 1 goto fail

echo.
echo Done. Your APK is at:
echo %cd%\build\app\outputs\flutter-apk\app-release.apk
goto end

:fail
echo.
echo Build failed. Read the error above, or run "flutter doctor" to check your setup.

:end
