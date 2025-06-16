import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
            'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      // case TargetPlatform.iOS:
      //   return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA7OtrMTwLlJyQMrg-lzPyCtE70BguE0ss',  // Aus der google-services.json
    appId: '1:672005927631:android:791c5cd4ddde33bf633dba',
    messagingSenderId: '672005927631',
    projectId: 'helpingpaw-6a513',
    storageBucket: 'helpingpaw-6a513.firebasestorage.app',
  );

  // iOS Konfiguration für später
  // static const FirebaseOptions ios = FirebaseOptions(
  //   apiKey: 'iOS_API_KEY',
  //   appId: 'iOS_APP_ID',
  //   messagingSenderId: 'SENDER_ID',
  //   projectId: 'DEIN_PROJECT_ID_HIER',
  //   storageBucket: 'DEIN_PROJECT_ID_HIER.appspot.com',
  //   iosBundleId: 'com.helpingpaw.frontend',
  // );
}