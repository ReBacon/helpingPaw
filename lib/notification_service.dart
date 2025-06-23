import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Einfache Initialisierung - keine komplexen Notifications
  static Future<void> initialize() async {
    print('🔊 NotificationService initialisiert (nur Sound)');
  }

  // Timer-Sound abspielen (statt Notification)
  static Future<void> showTimerFinishedNotification() async {
    // User-Einstellungen aus Firestore laden
    bool soundEnabled = await _getSoundSetting();

    if (!soundEnabled) {
      print('🔇 Sound ist deaktiviert');
      return;
    }

    // Einfach nur Sound abspielen
    await _playNotificationSound();

    print('🎵 Timer-Sound abgespielt (keine Notification)');
  }

  // Sound abspielen
  static Future<void> _playNotificationSound() async {
    try {
      // Plum Scream Sound abspielen
      await _audioPlayer.play(AssetSource('sounds/plumScream.m4a'));
      print('🔊 Plum Scream Sound abgespielt');
    } catch (e) {
      print('⚠️ Fehler beim Abspielen des Sounds: $e');
    }
  }

  // Sound-Einstellung aus Firestore laden
  static Future<bool> _getSoundSetting() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          return userData['soundEnabled'] ?? true;
        }
      }
    } catch (e) {
      print('⚠️ Fehler beim Laden der Sound-Einstellung: $e');
    }
    return true; // Default: aktiviert
  }

  // Test-Sound (für Debugging)
  static Future<void> showTestNotification() async {
    await _playNotificationSound();
    print('🎵 Test-Sound abgespielt');
  }

  // Cleanup
  static void dispose() {
    _audioPlayer.dispose();
  }
}