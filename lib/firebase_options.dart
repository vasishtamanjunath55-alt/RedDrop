import 'package:firebase_core/firebase_core.dart';

/// Paste your own Firebase values here (see README, step 3).
/// They come from the google-services.json you download in the Firebase console:
///   apiKey            -> client[0].api_key[0].current_key
///   appId             -> client[0].client_info.mobilesdk_app_id
///   messagingSenderId -> project_info.project_number
///   projectId         -> project_info.project_id
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDYL_D5vu8jm7xCS7i1_NwJ3IuMO9Ndvsc',
  appId: '1:157322263336:android:ce9b4025117210a251ae1d',
  messagingSenderId: '157322263336',
  projectId: 'reddrop-a2d8e',
);

bool get firebaseConfigured =>
    !firebaseOptions.apiKey.startsWith('PASTE') &&
    !firebaseOptions.appId.startsWith('PASTE') &&
    !firebaseOptions.projectId.startsWith('PASTE') &&
    !firebaseOptions.messagingSenderId.startsWith('PASTE');
