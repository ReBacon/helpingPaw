# 🐾 helpingPaw

A productivity app with heart - featuring two adorable cat companions that help you stay focused and organized!


<div align="center">
  <img src="assets/images/paw.png" alt="helpingPaw Logo" width="100" height="100">
</div>

## 📱 What is helpingPaw?

helpingPaw is a Flutter-based productivity application that combines essential productivity tools with delightful cat mascots. Unlike other sterile productivity apps, helpingPaw brings personality to your workflow with **Mimi** and **Mr. Plum**.

### 🐱 Meet Your Companions
- **Mimi**: Watches over your running timers and stays active while you work
- **Mr. Plum**: Alerts you when timers finish and celebrates your productivity milestones

## ✨ Features

### ⏰ Timer & Pomodoro
- **Custom Timer**: Set any duration for focused work sessions
- **Pomodoro Timer**: Built-in Pomodoro technique with customizable work/break intervals
- **Global Persistence**: Timers continue running even when navigating between screens
- **Smart Notifications**: Get alerted when sessions complete

### 📝 Secure Data Management
- **Encrypted Todo Lists**: AES-256 encryption for your tasks
- **Secure Notes**: Private note-taking with end-to-end encryption
- **User-Specific Keys**: Each user has their own encryption key derived from their UID

### 🎨 Personalization
- **6 Beautiful Themes**: Turquoise, Lavender, Peach, Sky Blue, Leaf, Rose
- **Responsive Design**: Optimized for all screen sizes (small, medium, large)
- **Clean UI**: Minimalist design focused on productivity

### 🔐 Security & Privacy
- **Firebase Authentication**: Secure user management
- **End-to-End Encryption**: All sensitive data encrypted before storage
- **Privacy-First**: Your data stays private and secure

## 🛠 Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Authentication + Firestore)
- **Security**: AES-256 encryption with SHA-256 key derivation
- **Architecture**: Global state management for persistent timers
- **Responsive**: Custom responsive helper for multi-device support

## 📦 Dependencies

```yaml
dependencies:
  flutter: sdk
  firebase_core: ^2.15.0
  firebase_auth: ^4.7.0
  cloud_firestore: ^4.8.0
  crypto: ^3.0.3
  encrypt: ^5.0.1
  audioplayers: ^5.0.0
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.2.0)
- Firebase project with Authentication and Firestore enabled
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/helpingpaw-portfolio.git
   cd helpingpaw-portfolio
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Replace the demo `firebase_options.dart` with your own configuration:
     ```bash
     # Install FlutterFire CLI
     dart pub global activate flutterfire_cli
     
     # Configure Firebase for your project
     flutterfire configure
     ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 🏗 Architecture Highlights

### Global Timer System
```dart
class GlobalTimer {
  static Timer? _timer;
  static bool _isRunning = false;
  static VoidCallback? _onTimerUpdate;
  
  // Timer persists across screen navigation
  static void toggleTimer() { /* ... */ }
}
```

### User-Specific Encryption
```dart
class EncryptionHelper {
  static String encryptText(String plainText, String userUID) {
    // Each user gets a unique encryption key
    final keyData = sha256.convert(utf8.encode(userUID + 'helpingPaw_secret_2024')).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyData.take(32).toList()));
    // AES-256 encryption
  }
}
```

### Responsive Design System
```dart
class ResponsiveHelper {
  static double getButtonHeight(BuildContext context) {
    if (isSmallScreen(context)) return 48;
    if (isMediumScreen(context)) return 56;
    return 64; // Automatic scaling
  }
}
```

## 🎯 Upcoming Features

- 📅 Calendar Integration
- 🔔 Advanced Reminders
- 📊 Productivity Statistics
- 🏆 Achievement System
- 🌙 Dark Mode Support

## 🤝 Development Partnership

This app was developed in collaboration with **Claude AI** (Anthropic), showcasing how human creativity and AI assistance can create something special together. Claude helped with:
- Code architecture and best practices
- Security implementation guidance
- UI/UX optimization suggestions
- Debugging complex state management issues

## 🐛 Known Issues

- Firebase configuration needs to be set up individually
- Large datasets may experience slight loading delays
- Theme switching requires app restart in some cases

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Mimi & Mr. Plum**: The real cats that inspired the app mascots
- **My Trainers**: For never giving up on me and motivating me to improve continuously
- **My Partner**: For always pointing out details and helping me find solutions ❤️
- **Flutter Team**: For the amazing framework
- **Firebase**: For reliable backend services
- **Claude AI**: For being an excellent coding partner

---

**Made with ❤️ and 🐾 by Rebecca**

*"Productivity doesn't have to be boring - let Mimi and Mr. Plum make your work day a little brighter!"*
