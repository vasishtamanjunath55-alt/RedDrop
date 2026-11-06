# RedDrop - Blood Donor and Emergency Request App

Flutter app. All data is stored on the phone (shared_preferences), so it runs with **no backend, no Firebase setup and no internet**. It ships with demo data so every screen has something to show.

## Demo logins

| Role | Email | Password |
|------|-------|----------|
| Demo user (donor + requester, B+, Bengaluru) | demo@reddrop.com | demo123 |
| Admin | admin@reddrop.com | admin123 |

The login screen also has "Demo user" and "Admin" buttons. Profile > "Reset demo data" restores the sample data.

## Features

1. Sign up / login with a role (donor, requester or both)
2. Donor profile: blood group, city, phone, "available now" toggle
3. Emergency request: blood group, units, hospital, city, urgency, deadline
4. Smart matching: compatible blood groups in the same city, ranked
5. Alerts for matching donors, who can accept or decline
6. Live request status: Open > Donor found > Fulfilled
7. Call and WhatsApp buttons
8. 90-day eligibility timer (donor hidden from alerts until eligible)
9. Donation history, log a donation, donor certificate
10. Badges and a leaderboard (filter by city)
11. Donation camps with register / cancel
12. Blood compatibility guide with a quick checker
13. Admin panel: verify or remove users, remove fake requests, add or remove camps
14. Impact dashboard: donors, requests, units, lives helped, charts

## Build the APK (pick ONE option)

### Option A - GitHub Actions (no installs, about 10 minutes)

1. Create a free account at github.com and click **New repository** (name it `reddrop`, keep it Public or Private).
2. Click **uploading an existing file**, drag in everything from this folder (including the hidden `.github` folder), and click **Commit changes**.
   - If the hidden folder is awkward to upload, install GitHub Desktop or run `git init`, `git add .`, `git commit`, `git push` from this folder.
3. Open the **Actions** tab. The "Build RedDrop APK" workflow starts by itself (or click it, then **Run workflow**).
4. Wait about 5 minutes for the green tick.
5. Open the finished run, scroll to **Artifacts**, download **reddrop-apk** (a zip), and unzip it to get `app-release.apk`.

### Option B - On your own computer

1. Install Flutter (docs.flutter.dev/get-started/install) and Android Studio (for the Android SDK). Run `flutter doctor` and fix anything marked with a red cross. Accept licenses with `flutter doctor --android-licenses`.
2. Open a terminal in this folder.
3. Run `build_apk.bat` (Windows) or `bash build_apk.sh` (Mac/Linux).
4. Your APK is at `build_app/build/app/outputs/flutter-apk/app-release.apk`.

Manual version of the same thing:

```
flutter create --platforms=android --org com.reddrop --project-name reddrop build_app
# copy this folder's lib/ and pubspec.yaml over build_app/lib and build_app/pubspec.yaml
cd build_app
flutter pub get
flutter build apk --release
```

## Install the APK on your phone

1. Send `app-release.apk` to your phone (USB cable, WhatsApp to yourself, Google Drive, or email).
2. Tap the file. If Android blocks it, tap **Settings** and allow **Install unknown apps** for the app you opened it from (Files, Chrome, WhatsApp...).
3. Tap **Install**, then **Open**.

## Run without building an APK (to test quickly)

Plug in an Android phone with USB debugging on, or start an emulator, then from `build_app`:

```
flutter run
```

## Notes for your presentation

- Phone numbers on the seeded donors are placeholders and will not connect when you tap Call. Sign up with your own number to demo calling.
- Alerts are created inside the app when a request is posted. Demo flow: log in as Demo user, post an O-/B+ request, log out, log in as another donor and show the alert, accept, then log back in as the requester and tap "Mark donated".
- To go beyond a local demo (real multi-device sync and push notifications), the next step is moving `lib/app_state.dart` to Firebase Auth + Firestore + Cloud Messaging.
