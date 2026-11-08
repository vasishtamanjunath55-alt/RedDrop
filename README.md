# RedDrop - Live Blood Donor and Emergency Request App

Flutter app with a real cloud backend. Accounts use **Firebase Authentication** and all data (profiles, requests, alerts, donations, camps) lives in **Cloud Firestore**, so every phone sees the same data in real time. There is no sample data: the app starts empty and fills up as real people sign up.

Alerts are live inside the app (they appear the moment a request is posted). They are not push notifications, so a donor sees them when the app is open.

## Features

1. Real sign up and login with a role (donor, requester or both)
2. Donor profile with blood group, city, phone and an availability switch
3. Emergency requests with urgency and deadline
4. Smart matching: compatible blood groups in the same city, ranked
5. Live alerts for matching donors, who can accept or decline
6. Live status: Open > Donor found > Fulfilled
7. Call and WhatsApp buttons
8. 90-day eligibility timer
9. Donation history, manual logging and donor certificate
10. Badges and leaderboard
11. Donation camps with registration
12. Blood compatibility guide
13. Admin panel (verify or remove users, remove requests, manage camps)
14. Impact dashboard

## Step 1 - Create the Firebase project (about 5 minutes)

1. Go to console.firebase.google.com and sign in with a Google account.
2. Click **Create a project**, name it `reddrop`, turn Google Analytics off, click **Create**.
3. In the left menu open **Build > Authentication**, click **Get started**, choose **Email/Password**, switch **Enable** on, click **Save**.
4. Open **Build > Firestore Database**, click **Create database**, pick a location near you (for India, `asia-south1` Mumbai), choose **Start in production mode**, click **Create**.
5. Open the **Rules** tab of Firestore, delete everything, paste the full contents of `firestore.rules` from this folder, and click **Publish**.

## Step 2 - Register the Android app

1. On the Firebase project home page click the **Android icon** (or Project settings > Your apps > Add app > Android).
2. Android package name: **`com.reddrop.reddrop`** (exactly). Leave the other fields empty and click **Register app**.
3. Click **Download google-services.json**. You only need to read it. You can skip the remaining steps in the wizard and close it.

## Step 3 - Paste four values into the app

Open `google-services.json` in Notepad and copy these into `lib/firebase_options.dart`:

| In google-services.json | In firebase_options.dart |
|---|---|
| `client` > `api_key` > `current_key` | `apiKey` |
| `client` > `client_info` > `mobilesdk_app_id` | `appId` |
| `project_info` > `project_number` | `messagingSenderId` |
| `project_info` > `project_id` | `projectId` |

Keep the quotes. The file should have no `PASTE_...` text left.

## Step 4 - Build the APK

**Option A - GitHub Actions (no installs):**
1. Upload this whole folder to your GitHub repository (replace the old files). The workflow in `.github/workflows/build-apk.yml` must be there.
2. Open the **Actions** tab, wait for the build (about 6 minutes) to turn green.
3. Open the run, download **reddrop-apk** under Artifacts, unzip it to get `app-release.apk`.

**Option B - On your computer** (Flutter and Android Studio installed): run `build_apk.bat` (Windows) or `bash build_apk.sh` (Mac/Linux). The APK ends up in `build_app/build/app/outputs/flutter-apk/`.

Install the APK on each phone (send it by WhatsApp or Drive, tap it, allow "Install unknown apps").

## Step 5 - Make yourself the admin

1. Open the app and sign up with your own account.
2. In the Firebase console open **Firestore Database > Data > users**, click your user document.
3. Change the field `role` to `admin` and save.
4. Close and reopen the app. You now see the Admin tab (add camps, verify donors, remove fake requests).

## Demo plan for the presentation

1. Phone A: sign up as a donor (for example O+, your city). Phone B: sign up as a requester.
2. Phone B posts a B+ request in the same city. Phone A (O+ can give to B+) gets the alert instantly.
3. Phone A taps **I can donate**. Phone B sees the status change to Donor found.
4. Phone B taps **Mark donated**. Phone A's history, badge and 90-day timer update.
5. Show the Impact dashboard and the admin panel.

Use at least two phones, or one phone and a friend's. An emulator also works.

## Notes and limits

- Phone numbers are visible to other signed-in users, because that is how people contact each other.
- Removing a user in the admin panel deletes their profile and requests. Their login stays in Firebase Authentication until you delete it in the console.
- To get push notifications when the app is closed, the next step is Firebase Cloud Messaging with a Cloud Function.
- If the app shows a red "Permission denied" banner, the Firestore rules in step 1.5 are not published yet.
