// This file is generated. DO NOT EDIT manually.
// To regenerate, run: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCo680PgxOp4Fwza9UC3aMqiBgtM_ModKw',
    appId: '1:982498733196:web:1e7bd657b809d1a96f9fa9',
    messagingSenderId: '982498733196',
    projectId: 'knowleg-33f36',
    authDomain: 'knowleg-33f36.firebaseapp.com',
    storageBucket: 'knowleg-33f36.firebasestorage.app',
    measurementId: 'G-8VCW7RYGEK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBwTSXx39yi3sFpX08jHK27M5hdBb5JaFU',
    appId: '1:982498733196:android:14611368e36393b16f9fa9',
    messagingSenderId: '982498733196',
    projectId: 'knowleg-33f36',
    storageBucket: 'knowleg-33f36.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBNGFBekl-DRmMoLhmfIclJByEzE55Re7Q',
    appId: '1:982498733196:ios:c01cf9c5613360c66f9fa9',
    messagingSenderId: '982498733196',
    projectId: 'knowleg-33f36',
    storageBucket: 'knowleg-33f36.firebasestorage.app',
    iosClientId: '982498733196-smt24dhid63l5tu4g7gmd8mj5t7qv9dk.apps.googleusercontent.com',
    iosBundleId: 'com.example.knowledgeFlow',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'ort-master-kg',
    storageBucket: 'ort-master-kg.appspot.com',
    iosBundleId: 'kg.ortmaster.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCo680PgxOp4Fwza9UC3aMqiBgtM_ModKw',
    appId: '1:982498733196:web:5badc392bc7830ad6f9fa9',
    messagingSenderId: '982498733196',
    projectId: 'knowleg-33f36',
    authDomain: 'knowleg-33f36.firebaseapp.com',
    storageBucket: 'knowleg-33f36.firebasestorage.app',
    measurementId: 'G-PGP4QS39K5',
  );

}