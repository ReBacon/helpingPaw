import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'style.dart';
import 'notification_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

//region x
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();

  // Timer mit Standardwerten initialisieren
  GlobalTimer.initializeDefault();
  GlobalPomodoroTimer.initializeDefault();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'helpingPaw',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

//endregion

//region enums
// Enum für Pomodoro-Phasen
enum PomodoroPhase {
  work,
  shortBreak,
  longBreak,
}
//endregion

//region Verschlüsselung (ENCRYPTION HELPER)
class EncryptionHelper {
  static encrypt.Encrypter? _encrypter;
  static encrypt.IV? _iv;

  // Verschlüsselungsschlüssel basierend auf User-UID generieren
  static void _initializeEncryption(String userUID) {
    // Erstelle einen konsistenten Schlüssel aus der UID
    final keyData = sha256.convert(utf8.encode(userUID + 'helpingPaw_secret_2024')).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyData.take(32).toList())); // AES-256

    // Feste IV aus UID generieren (für Konsistenz)
    final ivData = sha256.convert(utf8.encode(userUID + 'iv_salt')).bytes;
    _iv = encrypt.IV(Uint8List.fromList(ivData.take(16).toList())); // AES Block Size

    _encrypter = encrypt.Encrypter(encrypt.AES(key));
    print('🔐 Verschlüsselung initialisiert für User: ${userUID.substring(0, 8)}...');
  }

  // Text verschlüsseln
  static String encryptText(String plainText, String userUID) {
    try {
      if (_encrypter == null || _iv == null) {
        _initializeEncryption(userUID);
      }

      if (plainText.isEmpty) return plainText;

      final encrypted = _encrypter!.encrypt(plainText, iv: _iv!);
      return encrypted.base64;
    } catch (e) {
      print('❌ Verschlüsselungsfehler: $e');
      return plainText; // Fallback: unverschlüsselt zurückgeben
    }
  }

  // Text entschlüsseln
  static String decryptText(String encryptedText, String userUID) {
    try {
      if (_encrypter == null || _iv == null) {
        _initializeEncryption(userUID);
      }

      if (encryptedText.isEmpty) return encryptedText;

      // Prüfe ob der Text bereits verschlüsselt ist (Base64 format)
      if (!_isBase64(encryptedText)) {
        return encryptedText; // Unverschlüsselter Text (Backward Compatibility)
      }

      final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
      final decrypted = _encrypter!.decrypt(encrypted, iv: _iv!);
      return decrypted;
    } catch (e) {
      print('⚠️ Entschlüsselungsfehler: $e - Rückgabe als Klartext');
      return encryptedText; // Fallback: Text so zurückgeben wie er ist
    }
  }

  // Prüfe ob String Base64 ist
  static bool _isBase64(String str) {
    try {
      base64.decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Todo-Liste verschlüsseln
  static List<Map<String, dynamic>> encryptTodos(List<Map<String, dynamic>> todos, String userUID) {
    return todos.map((todo) {
      return {
        'id': todo['id'],
        'text': encryptText(todo['text'] ?? '', userUID),
        'completed': todo['completed'],
        'createdAt': todo['createdAt'],
      };
    }).toList();
  }

  // Todo-Liste entschlüsseln
  static List<Map<String, dynamic>> decryptTodos(List<dynamic> encryptedTodos, String userUID) {
    return encryptedTodos.map((todo) {
      return {
        'id': todo['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'text': decryptText(todo['text'] ?? '', userUID),
        'completed': todo['completed'] ?? false,
        'createdAt': todo['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      };
    }).toList();
  }

  // Notizen-Liste verschlüsseln
  static List<Map<String, dynamic>> encryptNotes(List<Map<String, dynamic>> notes, String userUID) {
    return notes.map((note) {
      return {
        'id': note['id'],
        'title': encryptText(note['title'] ?? '', userUID),
        'content': encryptText(note['content'] ?? '', userUID),
        'createdAt': note['createdAt'],
      };
    }).toList();
  }

  // Notizen-Liste entschlüsseln
  static List<Map<String, dynamic>> decryptNotes(List<dynamic> encryptedNotes, String userUID) {
    return encryptedNotes.map((note) {
      return {
        'id': note['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': decryptText(note['title'] ?? '', userUID),
        'content': decryptText(note['content'] ?? '', userUID),
        'createdAt': note['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      };
    }).toList();
  }

  // Cleanup
  static void dispose() {
    _encrypter = null;
    _iv = null;
  }
}
//endregion

//region timer

// Globale Timer-Klasse für persistenten Timer
class GlobalTimer {
  static Timer? _timer;
  static bool _isRunning = false;
  static int _currentHours = 0;
  static int _currentMinutes = 0;
  static int _currentSeconds = 0;
  static int _setHours = 0;
  static int _setMinutes = 0;
  static int _setSeconds = 0;
  static bool _isFinished = false;

  // Callback für UI-Updates
  static VoidCallback? _onTimerUpdate;
  static VoidCallback? _onTimerFinished;

  // Getter
  static bool get isRunning => _isRunning;
  static bool get isFinished => _isFinished;
  static int get currentHours => _currentHours;
  static int get currentMinutes => _currentMinutes;
  static int get currentSeconds => _currentSeconds;
  static int get setHours => _setHours;
  static int get setMinutes => _setMinutes;
  static int get setSeconds => _setSeconds;

  // Standardwerte setzen
  static void initializeDefault() {
    _setHours = 0;
    _setMinutes = 0;
    _setSeconds = 0;
    _currentHours = _setHours;
    _currentMinutes = _setMinutes;
    _currentSeconds = _setSeconds;
    _isFinished = false;
    _notifyUpdate();
  }

  // Timer-Zeit setzen
  static void setTime(int hours, int minutes, int seconds) {
    _setHours = hours;
    _setMinutes = minutes;
    _setSeconds = seconds;
    _currentHours = hours;
    _currentMinutes = minutes;
    _currentSeconds = seconds;
    _isFinished = false;
    _notifyUpdate();
  }

  // Timer starten/pausieren
  static void toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      _isRunning = false;
    } else {
      _isRunning = true;
      _isFinished = false;

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_currentSeconds > 0) {
          _currentSeconds--;
        } else if (_currentMinutes > 0) {
          _currentMinutes--;
          _currentSeconds = 59;
        } else if (_currentHours > 0) {
          _currentHours--;
          _currentMinutes = 59;
          _currentSeconds = 59;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _isFinished = true;
          NotificationService.showTimerFinishedNotification();
          _onTimerFinished?.call();
        }
        _notifyUpdate();
      });
    }
  }

  // Timer zurücksetzen
  static void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isFinished = false;
    _currentHours = _setHours;
    _currentMinutes = _setMinutes;
    _currentSeconds = _setSeconds;
    _notifyUpdate();
  }

  // Timer komplett neu
  static void newTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isFinished = false;
    _setHours = 0;
    _setMinutes = 0;
    _setSeconds = 0;
    _currentHours = 0;
    _currentMinutes = 0;
    _currentSeconds = 0;
    _notifyUpdate();
  }

  // Timer finished Status zurücksetzen
  static void clearFinished() {
    _isFinished = false;
    _notifyUpdate();
  }

  // Callbacks setzen
  static void setCallbacks({VoidCallback? onUpdate, VoidCallback? onFinished}) {
    _onTimerUpdate = onUpdate;
    _onTimerFinished = onFinished;
  }

  // Update benachrichtigen
  static void _notifyUpdate() {
    _onTimerUpdate?.call();
  }

  // Zeit formatieren
  static String getFormattedTime() {
    return '${_currentHours.toString().padLeft(2, '0')}:${_currentMinutes.toString().padLeft(2, '0')}:${_currentSeconds.toString().padLeft(2, '0')}';
  }

  // Display Text für HomeScreen
  static String getDisplayTimerText() {
    if (_isFinished) {
      return 'TIMER ABGELAUFEN!';
    }
    return getFormattedTime();
  }

  // Cleanup
  static void dispose() {
    _timer?.cancel();
    _onTimerUpdate = null;
    _onTimerFinished = null;
  }
}

// Globale Pomodoro-Timer-Klasse
class GlobalPomodoroTimer {
  static Timer? _timer;
  static bool _isRunning = false;
  static int _currentHours = 0;
  static int _currentMinutes = 0;
  static int _currentSeconds = 0;
  static bool _isFinished = false;

  // Pomodoro-spezifische Variablen
  static int _workTimeMinutes = 25;
  static int _shortBreakMinutes = 5;
  static int _longBreakMinutes = 15;
  static int _totalCycles = 5;
  static int _longBreakAfter = 4;

  // Aktuelle Phase tracking
  static PomodoroPhase _currentPhase = PomodoroPhase.work;
  static int _currentCycle = 1;
  static int _pauseCounter = 0;
  static bool _allCyclesCompleted = false;

  // Standard-Einstellungen
  static const int _defaultWorkTime = 25;
  static const int _defaultShortBreak = 5;
  static const int _defaultLongBreak = 15;
  static const int _defaultTotalCycles = 5;
  static const int _defaultLongBreakAfter = 4;

  // Callbacks
  static VoidCallback? _onTimerUpdate;
  static VoidCallback? _onTimerFinished;
  static VoidCallback? _onPhaseChange;

  // Getter
  static bool get isRunning => _isRunning;
  static bool get isFinished => _isFinished;
  static bool get allCyclesCompleted => _allCyclesCompleted;
  static int get currentHours => _currentHours;
  static int get currentMinutes => _currentMinutes;
  static int get currentSeconds => _currentSeconds;
  static PomodoroPhase get currentPhase => _currentPhase;
  static int get currentCycle => _currentCycle;
  static int get totalCycles => _totalCycles;
  static int get workTimeMinutes => _workTimeMinutes;
  static int get shortBreakMinutes => _shortBreakMinutes;
  static int get longBreakMinutes => _longBreakMinutes;
  static int get longBreakAfter => _longBreakAfter;

  // Einstellungen setzen
  static void setWorkTime(int minutes) {
    if (!_isRunning) {
      _workTimeMinutes = minutes;
      if (_currentPhase == PomodoroPhase.work) {
        _setCurrentTime(_workTimeMinutes);
      }
    }
  }

  static void setShortBreak(int minutes) {
    if (!_isRunning) {
      _shortBreakMinutes = minutes;
      if (_currentPhase == PomodoroPhase.shortBreak) {
        _setCurrentTime(_shortBreakMinutes);
      }
    }
  }

  static void setLongBreak(int minutes) {
    if (!_isRunning) {
      _longBreakMinutes = minutes;
      if (_currentPhase == PomodoroPhase.longBreak) {
        _setCurrentTime(_longBreakMinutes);
      }
    }
  }

  static void setTotalCycles(int cycles) {
    if (!_isRunning) {
      _totalCycles = cycles;
    }
  }

  static void setLongBreakAfter(int after) {
    if (!_isRunning) {
      _longBreakAfter = after;
    }
  }

  // Hilfsfunktion: Aktuelle Zeit basierend auf Phase setzen
  static void _setCurrentTime(int minutes) {
    _currentHours = 0;
    _currentMinutes = minutes;
    _currentSeconds = 0;
    _notifyUpdate();
  }

  // Timer starten/pausieren
  static void toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      _isRunning = false;
    } else {
      _isRunning = true;
      _isFinished = false;

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_currentSeconds > 0) {
          _currentSeconds--;
        } else if (_currentMinutes > 0) {
          _currentMinutes--;
          _currentSeconds = 59;
        } else if (_currentHours > 0) {
          _currentHours--;
          _currentMinutes = 59;
          _currentSeconds = 59;
        } else {
          _handlePhaseComplete();
        }
        _notifyUpdate();
      });
    }
  }

  // Phase abgeschlossen
  static void _handlePhaseComplete() {
    NotificationService.showTimerFinishedNotification();

    switch (_currentPhase) {
      case PomodoroPhase.work:
        _currentCycle++;

        if (_currentCycle > _totalCycles) {
          // Alle Zyklen abgeschlossen - Timer stoppen und als finished markieren
          _timer?.cancel();
          _isRunning = false;
          _isFinished = true;
          _allCyclesCompleted = true;
          _onTimerFinished?.call();
          return;
        } else {
          // Nur Pause starten wenn noch weitere Zyklen kommen
          _pauseCounter++;

          if (_pauseCounter % _longBreakAfter == 0) {
            _currentPhase = PomodoroPhase.longBreak;
            _setCurrentTime(_longBreakMinutes);
          } else {
            _currentPhase = PomodoroPhase.shortBreak;
            _setCurrentTime(_shortBreakMinutes);
          }
        }
        break;

      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        _currentPhase = PomodoroPhase.work;
        _setCurrentTime(_workTimeMinutes);
        break;
    }

    _onPhaseChange?.call();
  }

  // Alle Zyklen abgeschlossen
  static void _completeAllCycles() {
    _timer?.cancel();
    _isRunning = false;
    _isFinished = true;
    _allCyclesCompleted = true;
    _onTimerFinished?.call();
  }

  // Timer zurücksetzen
  static void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isFinished = false;
    _allCyclesCompleted = false;
    _currentPhase = PomodoroPhase.work;
    _currentCycle = 1;
    _pauseCounter = 0;
    _setCurrentTime(_workTimeMinutes);
    _notifyUpdate();
  }

  // Neuer Timer
  static void newTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isFinished = false;
    _allCyclesCompleted = false;

    _workTimeMinutes = _defaultWorkTime;
    _shortBreakMinutes = _defaultShortBreak;
    _longBreakMinutes = _defaultLongBreak;
    _totalCycles = _defaultTotalCycles;
    _longBreakAfter = _defaultLongBreakAfter;

    _currentPhase = PomodoroPhase.work;
    _currentCycle = 1;
    _pauseCounter = 0;
    _setCurrentTime(_workTimeMinutes);
    _notifyUpdate();
  }

  // Timer finished Status zurücksetzen
  static void clearFinished() {
    _isFinished = false;
    _allCyclesCompleted = false;
    _notifyUpdate();
  }

  // Callbacks setzen
  static void setCallbacks({
    VoidCallback? onUpdate,
    VoidCallback? onFinished,
    VoidCallback? onPhaseChange
  }) {
    _onTimerUpdate = onUpdate;
    _onTimerFinished = onFinished;
    _onPhaseChange = onPhaseChange;
  }

  // Update benachrichtigen
  static void _notifyUpdate() {
    _onTimerUpdate?.call();
  }

  // Zeit formatieren
  static String getFormattedTime() {
    return '${_currentHours.toString().padLeft(2, '0')}:${_currentMinutes.toString().padLeft(2, '0')}:${_currentSeconds.toString().padLeft(2, '0')}';
  }

  // Display Text für HomeScreen
  static String getDisplayPomodoroText() {
    if (_allCyclesCompleted) {
      return 'POMODORO ABGELAUFEN!';
    }
    return getFormattedTime();
  }

  // Phase als Text
  static String getPhaseText() {
    switch (_currentPhase) {
      case PomodoroPhase.work:
        return 'ARBEITSZEIT (${_currentCycle}/${_totalCycles})';
      case PomodoroPhase.shortBreak:
        return 'KURZE PAUSE';
      case PomodoroPhase.longBreak:
        return 'LANGE PAUSE';
    }
  }

  // Initialisierung mit Standard-Werten
  static void initializeDefault() {
    newTimer();
  }

  // Cleanup
  static void dispose() {
    _timer?.cancel();
    _onTimerUpdate = null;
    _onTimerFinished = null;
    _onPhaseChange = null;
  }
}
//endregion

//#region LoginScreen
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      await AppTheme.loadTurquoiseTheme();
    } catch (e) {
      print('⚠️ Theme laden fehlgeschlagen, verwende Default: $e');
      AppTheme.loadDefaultTheme();
    }

    setState(() {
      _themeLoaded = true;
    });
  }

  Future<void> _login() async {
    // 1. Alle Felder ausgefüllt?
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.colors.mainBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Text(
              '📝 Bitte fülle alle Felder aus!',
              style: AppStyles.fieldStyle(context),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text('OK', style: AppStyles.buttonStyle(context)),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // 2. E-Mail Format prüfen
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.colors.mainBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Text(
              '📧 Bitte gib eine gültige E-Mail-Adresse ein!',
              style: AppStyles.fieldStyle(context),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text('OK', style: AppStyles.buttonStyle(context)),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // 3. Login versuchen
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // Theme laden nach erfolgreichem Login
        await AppTheme.loadUserTheme();

        // EXPLIZITE Navigation zum HomeScreen
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomeScreen()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      print('⚠️ Login Fehler: $e');

      // Prüfen ob User trotz Error eingeloggt ist
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('✅ User ist trotz Error eingeloggt - UID: ${currentUser.uid}');
        // Theme laden nach erfolgreichem Login
        await AppTheme.loadUserTheme();

        // EXPLIZITE Navigation zum HomeScreen
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomeScreen()),
                (route) => false,
          );
        }
      } else {
        // 4. Echter Login-Fehler (E-Mail/Passwort falsch)
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppTheme.colors.mainBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              content: Text(
                '🔐 E-Mail oder Passwort ist falsch. Bitte versuche es nochmal!',
                style: AppStyles.fieldStyle(context),
                textAlign: TextAlign.center,
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: AppStyles.getElevatedButtonStyle(),
                    child: Text('OK', style: AppStyles.buttonStyle(context)),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: ResponsiveHelper.getLogoSize(context),
                height: ResponsiveHelper.getLogoSize(context),
                child: Image.asset(
                  'assets/images/paw.png',
                  color: AppTheme.colors.mainTextColor,
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                'helpingPaw',
                style: AppStyles.titleStyle(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 60),
              Container(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _emailController,
                  decoration: AppStyles.getInputDecoration(context, 'E-MAIL'),
                  style: AppStyles.fieldStyle(context),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              SizedBox(height: 20),
              Container(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _passwordController,
                  decoration: AppStyles.getInputDecoration(context, 'PASSWORT'),
                  style: AppStyles.fieldStyle(context),
                  obscureText: true,
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: ResponsiveHelper.getMaxWidth(context) - 40,
                height: ResponsiveHelper.getButtonHeight(context),
                child: ElevatedButton(
                  onPressed: _login,
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text(
                    'LOGIN',
                    style: AppStyles.buttonStyle(context),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
                child: Text(
                  'NOCH KEIN KONTO? -> REGISTRIEREN',
                  style: AppStyles.labelStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.8,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
//#endregion

//#region RegisterScreen
class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _errorMessage = '';
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      await AppTheme.loadTurquoiseTheme();
    } catch (e) {
      print('⚠️ Theme laden fehlgeschlagen, verwende Default: $e');
      AppTheme.loadDefaultTheme();
    }

    setState(() {
      _themeLoaded = true;
    });
  }

  Future<void> _register() async {
    // 1. Alle Felder ausgefüllt?
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.colors.mainBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Text(
              '📝 Bitte fülle alle Felder aus!',
              style: AppStyles.fieldStyle(context),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text('OK', style: AppStyles.buttonStyle(context)),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // 2. E-Mail Format prüfen
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.colors.mainBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Text(
              '📧 Bitte gib eine gültige E-Mail-Adresse ein!',
              style: AppStyles.fieldStyle(context),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text('OK', style: AppStyles.buttonStyle(context)),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // 3. Passwort Länge prüfen
    if (_passwordController.text.length < 6) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.colors.mainBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Text(
              '🔑 Das Passwort muss mindestens 6 Zeichen lang sein!',
              style: AppStyles.fieldStyle(context),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text('OK', style: AppStyles.buttonStyle(context)),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // 4. Passwörter stimmen überein?
    if (_passwordController.text != _confirmPasswordController.text) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppTheme.colors.mainBackground,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            content: Text(
              '🔒 Die Passwörter stimmen nicht überein!',
              style: AppStyles.fieldStyle(context),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text('OK', style: AppStyles.buttonStyle(context)),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() {
      _errorMessage = '';
    });

    try {
      print('🔧 Starte Registrierung für: ${_emailController.text.trim()}');

      // Loading Dialog anzeigen
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Registrierung läuft..."),
                ],
              ),
            );
          },
        );
      }

      // 1. Firebase Auth User erstellen
      UserCredential? userCredential;
      String? uid;

      try {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        uid = userCredential.user?.uid;
        print('✅ Firebase Auth erfolgreich - UID: $uid');
      } catch (authError) {
        // Falls Cast-Fehler in Firebase Auth - User ist trotzdem erstellt!
        print('⚠️ Firebase Auth Cast-Fehler (ignoriert): $authError');

        // Hole den aktuell eingeloggten User
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          uid = currentUser.uid;
          print('✅ User trotzdem erfolgreich erstellt - UID: $uid');
        } else {
          throw Exception('User konnte nicht erstellt werden');
        }
      }

      if (uid != null) {
        final String email = _emailController.text.trim();

        // 2. User-Dokument erstellen
        print('🔧 Erstelle User-Dokument für UID: $uid');
        await FirebaseFirestore.instance
            .collection('user')
            .doc(uid)
            .set({
          'email': email,
          'themeID': 'turquoise',
          'notificationsEnabled': true,
          'soundEnabled': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ User-Dokument erstellt');

        // 3. Todo-Dokument erstellen
        print('🔧 Erstelle verschlüsseltes Todo-Dokument für UID: $uid');
        await FirebaseFirestore.instance
            .collection('todos')
            .doc(uid)
            .set({
          'todoList': [],
          'encrypted': true, // 🔐 MARKIERUNG FÜR VERSCHLÜSSELUNG
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('✅ Verschlüsseltes Todo-Dokument erstellt');

        // 4. Notes-Dokument erstellen
        print('🔧 Erstelle verschlüsseltes Notes-Dokument für UID: $uid');
        try {
          await FirebaseFirestore.instance
              .collection('notes')
              .doc(uid)
              .set({
            'noteList': [],
            'encrypted': true, // 🔐 MARKIERUNG FÜR VERSCHLÜSSELUNG
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print('✅ Verschlüsseltes Notes-Dokument erstellt');
        } catch (notesError) {
          print('⚠️ Notes-Dokument Fehler (wird ignoriert): $notesError');
        }

        // Loading Dialog schließen
        if (mounted) {
          Navigator.of(context).pop();
        }

      // 5. Welcome Dialog ZUERST zeigen, dann zum HomeScreen
        print('🚀 Zeige Welcome Dialog...');
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return InfoScreen(showAsWelcome: true);
            },
          ).then((_) {
            // Nach Dialog-Schließung zum HomeScreen
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomeScreen()),
                    (route) => false,
              );
            }
          });
        }
        print('✅ Registrierung erfolgreich abgeschlossen!');
      } else {
        throw Exception('User konnte nicht erstellt werden');
      }
    } catch (e) {
      print('❌ Registrierung fehlgeschlagen: $e');

      // Loading Dialog schließen falls noch offen
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }

      // Fehler-Dialog anzeigen
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppTheme.colors.mainBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              content: Text(
                '😿 Ups! Etwas ist schiefgelaufen. Bitte versuche es nochmal!',
                style: AppStyles.fieldStyle(context),
                textAlign: TextAlign.center,
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: AppStyles.getElevatedButtonStyle(),
                    child: Text('OK', style: AppStyles.buttonStyle(context)),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.colors.mainBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.colors.mainTextColor),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: ResponsiveHelper.getLogoSize(context),
                height: ResponsiveHelper.getLogoSize(context),
                child: Image.asset(
                  'assets/images/paw.png',
                  color: AppTheme.colors.mainTextColor,
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                'REGISTRIEREN',
                style: AppStyles.titleStyle(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              Container(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _emailController,
                  decoration: AppStyles.getInputDecoration(context, 'E-MAIL'),
                  style: AppStyles.fieldStyle(context),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              SizedBox(height: 20),
              Container(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _passwordController,
                  decoration: AppStyles.getInputDecoration(context, 'PASSWORT'),
                  style: AppStyles.fieldStyle(context),
                  obscureText: true,
                ),
              ),
              SizedBox(height: 20),
              Container(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _confirmPasswordController,
                  decoration: AppStyles.getInputDecoration(context, 'PASSWORT BESTÄTIGEN'),
                  style: AppStyles.fieldStyle(context),
                  obscureText: true,
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: ResponsiveHelper.getMaxWidth(context) - 40,
                height: ResponsiveHelper.getButtonHeight(context),
                child: ElevatedButton(
                  onPressed: _register,
                  style: AppStyles.getElevatedButtonStyle(),
                  child: Text(
                    'REGISTRIEREN',
                    style: AppStyles.buttonStyle(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
//#endregion

//#region HomeScreen
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _themeLoaded = false;
  String _selectedTheme = 'turquoise';
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _setupTimerCallbacks();
    _setupPomodoroCallbacks();
    _startUIUpdateTimer();
  }

  Future<void> _loadUserTheme() async {
    if (!mounted) return; // Prüfe ob Widget noch gemounted ist

    try {
      print('🎨 HomeScreen: Lade User Theme...');
      await AppTheme.loadUserTheme();

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && mounted) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && mounted) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          _selectedTheme = userData['themeID'] ?? 'turquoise';
          print('🎨 Theme ID gefunden: $_selectedTheme');
        }
      }
    } catch (e) {
      print('❌ Fehler beim Laden der Theme-ID: $e');
      _selectedTheme = 'turquoise'; // Fallback
    }

    if (mounted) {
      setState(() {
        _themeLoaded = true;
      });
      print('✅ HomeScreen Theme Loading abgeschlossen');
    }
  }

  void _setupTimerCallbacks() {
    GlobalTimer.setCallbacks(
      onUpdate: () {
        if (mounted) {
          setState(() {
            if (GlobalTimer.isRunning) {
              print('🔄 HomeScreen Timer Update: ${GlobalTimer.getDisplayTimerText()}');
            }
          });
        }
      },
      onFinished: () {
        if (mounted) {
          setState(() {
            print('⏰ HomeScreen Timer Finished!');
          });
        }
      },
    );
  }

  void _setupPomodoroCallbacks() {
    GlobalPomodoroTimer.setCallbacks(
      onUpdate: () {
        if (mounted) {
          setState(() {
            if (GlobalPomodoroTimer.isRunning) {
              print('🍅 HomeScreen Pomodoro Update: ${GlobalPomodoroTimer.getDisplayPomodoroText()}');
            }
          });
        }
      },
      onFinished: () {
        if (mounted) {
          setState(() {
            print('🍅 HomeScreen Pomodoro Finished!');
          });
        }
      },
      onPhaseChange: () {
        if (mounted) {
          setState(() {
            print('🍅 HomeScreen Pomodoro Phase Change: ${GlobalPomodoroTimer.getPhaseText()}');
          });
        }
      },
    );
  }

  void _startUIUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (mounted && (GlobalTimer.isRunning || GlobalPomodoroTimer.isRunning)) {
        setState(() {});
      }
    });
  }

  void _onPlumTapped() {
    if (GlobalTimer.isFinished) {
      GlobalTimer.clearFinished();
      print('🐱 Plum getappt - Timer finished Status zurückgesetzt');
    } else if (GlobalPomodoroTimer.allCyclesCompleted) {
      GlobalPomodoroTimer.clearFinished();
      print('🐱 Plum getappt - Pomodoro finished Status zurückgesetzt');
    }
  }

  Widget _buildTimerDisplay() {
    String displayText = GlobalTimer.getDisplayTimerText();
    bool isFinished = GlobalTimer.isFinished;
    bool isRunning = GlobalTimer.isRunning;

    if (isRunning) {
      print('🖥️ HomeScreen Timer Display: $displayText (Running: $isRunning, Finished: $isFinished)');
    }

    if (!isRunning && !isFinished) {
      return Container();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TimerScreen()),
        );
      },
      child: Container(
        width: ResponsiveHelper.getMaxWidth(context) - 40,
        height: ResponsiveHelper.getMenuButtonHeight(context) * 2.5,
        decoration: BoxDecoration(
          color: AppTheme.colors.mainBackground2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                displayText,
                style: isFinished
                    ? AppStyles.buttonStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 0.6,
                  color: AppTheme.colors.mainTextColor,
                  fontWeight: FontWeight.normal,
                )
                    : AppStyles.fieldStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 1.2,
                  color: AppTheme.colors.mainTextColor,
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPomodoroDisplay() {
    String displayText = GlobalPomodoroTimer.getDisplayPomodoroText();
    String phaseText = GlobalPomodoroTimer.getPhaseText();
    bool isFinished = GlobalPomodoroTimer.allCyclesCompleted;
    bool isRunning = GlobalPomodoroTimer.isRunning;

    if (isRunning) {
      print('🖥️ HomeScreen Pomodoro Display: $displayText (Running: $isRunning, Finished: $isFinished)');
    }

    if (!isRunning && !isFinished) {
      return Container();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PomodoroScreen()),
        );
      },
      child: Container(
        width: ResponsiveHelper.getMaxWidth(context) - 40,
        height: ResponsiveHelper.getMenuButtonHeight(context) * 2.5,
        decoration: BoxDecoration(
          color: AppTheme.colors.mainBackground2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isFinished) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    phaseText,
                    style: AppStyles.labelStyle(context).copyWith(
                      fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.6,
                      color: AppTheme.colors.mainTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 4),
              ],

              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    displayText,
                    style: isFinished
                        ? AppStyles.buttonStyle(context).copyWith(
                      fontSize: ResponsiveHelper.getTitleFontSize(context) * 0.6,
                      color: AppTheme.colors.mainTextColor,
                      fontWeight: FontWeight.normal,
                    )
                        : AppStyles.fieldStyle(context).copyWith(
                      fontSize: ResponsiveHelper.getTitleFontSize(context) * 1.2,
                      color: AppTheme.colors.mainTextColor,
                      fontWeight: FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: Stack(
        children: [
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/cattreeColor.png',
                height: MediaQuery.of(context).size.height * 0.5,
                fit: BoxFit.fitHeight,
              ),
            ),
          ),

          // Mimi Katze - reagiert auf Timer UND Pomodoro
          Positioned(
            bottom: (GlobalTimer.isRunning || GlobalPomodoroTimer.isRunning) ? 160 : 130,
            left: (GlobalTimer.isRunning || GlobalPomodoroTimer.isRunning) ? 130 : 120,
            right: 0,
            child: Transform.scale(
              scaleX: -1,
              child: GestureDetector(
                onTap: () {
                  print('🐱 Mimi getappt - Timer läuft: ${GlobalTimer.isRunning}, Pomodoro läuft: ${GlobalPomodoroTimer.isRunning}');
                },
                child: Image.asset(
                  (GlobalTimer.isRunning || GlobalPomodoroTimer.isRunning) ? 'assets/images/mimiSit.png' : 'assets/images/mimiSleep.png',
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ),

          // Plum Katze - reagiert auf Timer finished ODER Pomodoro finished
          Positioned(
            bottom: (GlobalTimer.isFinished || GlobalPomodoroTimer.allCyclesCompleted) ? 360 : 328,
            left: (GlobalTimer.isFinished || GlobalPomodoroTimer.allCyclesCompleted) ? 90 : 115,
            right: 0,
            child: GestureDetector(
              onTap: _onPlumTapped,
              child: Image.asset(
                (GlobalTimer.isFinished || GlobalPomodoroTimer.allCyclesCompleted) ? 'assets/images/plumSit.png' : 'assets/images/plumSleep.png',
                width: 160,
                height: 160,
              ),
            ),
          ),

          // Pfote rechts oben (Menü)
          Positioned(
            top: 50,
            right: 20,
            child: AppWidgets.pawPlusButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MenuScreen()),
                );
                await _loadUserTheme();
                _setupTimerCallbacks();
                _setupPomodoroCallbacks();
              },
            ),
          ),

          // Timer/Pomodoro Display zwischen Menü und Grafiken
          Positioned(
            top: MediaQuery.of(context).size.height * 0.17,
            left: 20,
            right: 20,
            child: Column(
              children: [
                _buildTimerDisplay(),
                if ((GlobalTimer.isRunning || GlobalTimer.isFinished) &&
                    (GlobalPomodoroTimer.isRunning || GlobalPomodoroTimer.allCyclesCompleted))
                  SizedBox(height: 10),
                _buildPomodoroDisplay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }
}
//#endregion

//#region MenuScreen
class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();
    setState(() {
      _themeLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'MENÜ',
                      style: AppStyles.titleStyle(context).copyWith(
                        fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Menu-Buttons
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      AppWidgets.menuButton(
                        text: 'TIMER',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TimerScreen()),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'POMODORO-TIMER',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PomodoroScreen()),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'TODO-LISTE',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TodoListScreen()),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'NOTIZEN',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => NotesScreen()),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'ERINNERUNGEN',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erinnerungen - Coming Soon!')),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'KALENDER',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kalender - Coming Soon!')),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'EINSTELLUNGEN',
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SettingsScreen()),
                          );
                          await _loadUserTheme();
                        },
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Paw Footer
            Padding(
              padding: EdgeInsets.all(10),
              child: AppWidgets.pawBackButton(
                onPressed: () => Navigator.pop(context),
                isBackButton: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//#endregion

//#region SettingsScreen
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _themeLoaded = false;
  String _selectedTheme = 'turquoise';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  final Map<String, Map<String, Color>> _themeColors = {
    'turquoise': {
      'background2': Color(0xFF88D1CA),
      'background': Color(0xFFC7F0EC),
      'textColor': Color(0xFF40615F),
    },
    'lavender': {
      'background2': Color(0xFFB8A6D9),
      'background': Color(0xFFE0D7EF),
      'textColor': Color(0xFF483371),
    },
    'peach': {
      'background2': Color(0xFFFFCBA4),
      'background': Color(0xFFFFE8D6),
      'textColor': Color(0xFF8A512E),
    },
    'skyblue': {
      'background2': Color(0xFFA4C8E9),
      'background': Color(0xFFD6E8F4),
      'textColor': Color(0xFF1F4567),
    },
    'leaf': {
      'background2': Color(0xFFA3D9A1),
      'background': Color(0xFFD2F0CD),
      'textColor': Color(0xFF224E23),
    },
    'rose': {
      'background2': Color(0xFFECC8D3),
      'background': Color(0xFFF9E4EB),
      'textColor': Color(0xFF653144),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    await AppTheme.loadUserTheme();

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String,
              dynamic>;
          setState(() {
            _selectedTheme = userData['themeID'] ?? 'turquoise';
            _notificationsEnabled = userData['notificationsEnabled'] ?? true;
            _soundEnabled = userData['soundEnabled'] ?? true;
          });
        }
      }
    } catch (e) {
      print('Fehler beim Laden der User-Einstellungen: $e');
    }

    setState(() {
      _themeLoaded = true;
    });
  }

  Future<void> _updateUserTheme(String themeID) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('user')
            .doc(currentUser.uid)
            .update({'themeID': themeID});

        setState(() {
          _selectedTheme = themeID;
        });

        await AppTheme.loadUserTheme();
        setState(() {});
      }
    } catch (e) {
      print('Fehler beim Aktualisieren des Themes: $e');
      await AppTheme.loadUserTheme();
      setState(() {
        _selectedTheme = themeID;
      });
    }
  }

  Future<void> _updateUserSetting(String setting, bool value) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('user')
            .doc(currentUser.uid)
            .update({setting: value});

        setState(() {
          if (setting == 'notificationsEnabled') {
            _notificationsEnabled = value;
          } else if (setting == 'soundEnabled') {
            _soundEnabled = value;
          }
        });
      }
    } catch (e) {
      print('Fehler beim Aktualisieren der Einstellung: $e');
      setState(() {
        if (setting == 'notificationsEnabled') {
          _notificationsEnabled = value;
        } else if (setting == 'soundEnabled') {
          _soundEnabled = value;
        }
      });
    }
  }

  Widget _buildThemePreview(String themeId) {
    final colors = _themeColors[themeId];
    if (colors == null) return Container();

    return GestureDetector(
      onTap: () => _updateUserTheme(themeId),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: colors['background2'],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedTheme == themeId
                ? AppTheme.colors.mainTextColor
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors['background'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colors['textColor'],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(String title, bool value,
      Function(bool) onChanged) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppStyles.labelStyle(context).copyWith(
              fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.8,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.colors.mainTextColor,
            activeTrackColor: AppTheme.colors.mainBackground2,
            inactiveThumbColor: AppTheme.colors.mainBackground2,
            inactiveTrackColor: AppTheme.colors.mainTextColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              child: Text(
                'EINSTELLUNGEN',
                style: AppStyles.titleStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.8,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 30),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildThemePreview('turquoise'),
                              _buildThemePreview('lavender'),
                              _buildThemePreview('peach'),
                            ],
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildThemePreview('skyblue'),
                              _buildThemePreview('leaf'),
                              _buildThemePreview('rose'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40),
                    _buildSettingSwitch(
                      'BENACHRICHTIGUNG',
                      _notificationsEnabled,
                          (value) =>
                          _updateUserSetting('notificationsEnabled', value),
                    ),
                    _buildSettingSwitch(
                      'TON',
                      _soundEnabled,
                          (value) => _updateUserSetting('soundEnabled', value),
                    ),
                    SizedBox(height: 30),

                    // INFORMATIONEN Button - NEU HINZUGEFÜGT
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: AppWidgets.menuButton(
                        text: 'INFORMATIONEN',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => InfoScreen()),
                          );
                        },
                        context: context,
                      ),
                    ),
                    SizedBox(height: 15),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: AppWidgets.menuButton(
                        text: 'LOGOUT',
                        onPressed: () async {
                          EncryptionHelper.dispose();
                          await FirebaseAuth.instance.signOut();

                          // RICHTIGE Navigation zum LoginScreen
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                                (route) => false,
                          );
                        },
                        context: context,
                      ),
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: AppWidgets.menuButton(
                        text: 'BEENDEN',
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: AppWidgets.pawBackButton(
                onPressed: () => Navigator.pop(context),
                isBackButton: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//#endregionr

//#region TimerScreen
class TimerScreen extends StatefulWidget {
  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  bool _themeLoaded = false;
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _setupTimerCallbacks();
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();
    setState(() {
      _themeLoaded = true;
    });
  }

  void _setupTimerCallbacks() {
    GlobalTimer.setCallbacks(
      onUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
      onFinished: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // Gedrückt-halten starten
  void _startRepeating(VoidCallback action) {
    action(); // Erste Ausführung sofort
    _repeatTimer = Timer.periodic(Duration(milliseconds: 150), (timer) {
      action();
    });
  }

  // Gedrückt-halten stoppen
  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  // Zeit einstellen Dialog
  void _showTimeSetDialog() {
    if (GlobalTimer.isRunning) return; // Nicht während Timer läuft

    int tempHours = GlobalTimer.setHours;
    int tempMinutes = GlobalTimer.setMinutes;
    int tempSeconds = GlobalTimer.setSeconds;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.colors.mainBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                'ZEIT EINSTELLEN',
                style: AppStyles.labelStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              content: Container(
                height: 120,
                child: Column(
                  children: [
                    // Stunden
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'STUNDEN',
                          style: AppStyles.labelStyle(context).copyWith(
                            fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempHours = tempHours > 0 ? tempHours - 1 : 23;
                                });
                              },
                              onLongPressStart: (_) => _startRepeating(() {
                                setDialogState(() {
                                  tempHours = tempHours > 0 ? tempHours - 1 : 23;
                                });
                              }),
                              onLongPressEnd: (_) => _stopRepeating(),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.remove, color: AppTheme.colors.mainTextColor),
                              ),
                            ),
                            Container(
                              width: 50,
                              child: Text(
                                tempHours.toString().padLeft(2, '0'),
                                style: AppStyles.fieldStyle(context).copyWith(fontSize: 23),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempHours = tempHours < 23 ? tempHours + 1 : 0;
                                });
                              },
                              onLongPressStart: (_) => _startRepeating(() {
                                setDialogState(() {
                                  tempHours = tempHours < 23 ? tempHours + 1 : 0;
                                });
                              }),
                              onLongPressEnd: (_) => _stopRepeating(),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.add, color: AppTheme.colors.mainTextColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Minuten
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MINUTEN',
                          style: AppStyles.labelStyle(context).copyWith(
                            fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempMinutes = tempMinutes > 0 ? tempMinutes - 1 : 59;
                                });
                              },
                              onLongPressStart: (_) => _startRepeating(() {
                                setDialogState(() {
                                  tempMinutes = tempMinutes > 0 ? tempMinutes - 1 : 59;
                                });
                              }),
                              onLongPressEnd: (_) => _stopRepeating(),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.remove, color: AppTheme.colors.mainTextColor),
                              ),
                            ),
                            Container(
                              width: 50,
                              child: Text(
                                tempMinutes.toString().padLeft(2, '0'),
                                style: AppStyles.fieldStyle(context).copyWith(fontSize: 23),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempMinutes = tempMinutes < 59 ? tempMinutes + 1 : 0;
                                });
                              },
                              onLongPressStart: (_) => _startRepeating(() {
                                setDialogState(() {
                                  tempMinutes = tempMinutes < 59 ? tempMinutes + 1 : 0;
                                });
                              }),
                              onLongPressEnd: (_) => _stopRepeating(),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.add, color: AppTheme.colors.mainTextColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Sekunden
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SEKUNDEN',
                          style: AppStyles.labelStyle(context).copyWith(
                            fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempSeconds = tempSeconds > 0 ? tempSeconds - 1 : 59;
                                });
                              },
                              onLongPressStart: (_) => _startRepeating(() {
                                setDialogState(() {
                                  tempSeconds = tempSeconds > 0 ? tempSeconds - 1 : 59;
                                });
                              }),
                              onLongPressEnd: (_) => _stopRepeating(),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.remove, color: AppTheme.colors.mainTextColor),
                              ),
                            ),
                            Container(
                              width: 50,
                              child: Text(
                                tempSeconds.toString().padLeft(2, '0'),
                                style: AppStyles.fieldStyle(context).copyWith(fontSize: 23),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempSeconds = tempSeconds < 59 ? tempSeconds + 1 : 0;
                                });
                              },
                              onLongPressStart: (_) => _startRepeating(() {
                                setDialogState(() {
                                  tempSeconds = tempSeconds < 59 ? tempSeconds + 1 : 0;
                                });
                              }),
                              onLongPressEnd: (_) => _stopRepeating(),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.add, color: AppTheme.colors.mainTextColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      GlobalTimer.setTime(tempHours, tempMinutes, tempSeconds);
                      Navigator.pop(context);
                    },
                    style: AppStyles.getElevatedButtonStyle(),
                    child: Text(
                      'OK',
                      style: AppStyles.buttonStyle(context),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(10),
              child: Text(
                'TIMER',
                style: AppStyles.titleStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.8,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Timer Display
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: ResponsiveHelper.getMaxWidth(context) - 40,
                      margin: EdgeInsets.only(bottom: 5),
                      child: Text(
                        'ZEIT EINSTELLEN',
                        style: AppStyles.labelStyle(context).copyWith(
                          fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.1,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),

                    // Zeit-Anzeige (klickbar)
                    GestureDetector(
                      onTap: _showTimeSetDialog,
                      child: Container(
                        width: ResponsiveHelper.getMaxWidth(context) - 40,
                        height: ResponsiveHelper.getMenuButtonHeight(context) * 2.5,
                        decoration: BoxDecoration(
                          color: AppTheme.colors.mainBackground2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                GlobalTimer.getDisplayTimerText(),
                                style: GlobalTimer.isFinished
                                    ? AppStyles.buttonStyle(context).copyWith(
                                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 0.6,
                                  color: AppTheme.colors.mainTextColor,
                                  fontWeight: FontWeight.normal,
                                )
                                    : AppStyles.fieldStyle(context).copyWith(
                                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 1.2,
                                  color: AppTheme.colors.mainTextColor,
                                  fontWeight: FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 60),

                    // START/PAUSE Button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: AppWidgets.menuButton(
                        text: GlobalTimer.isRunning ? 'PAUSE' : 'START',
                        onPressed: () {
                          GlobalTimer.toggleTimer();
                        },
                        context: context,
                      ),
                    ),

                    SizedBox(height: 15),

                    // RESET Button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: AppWidgets.menuButton(
                        text: 'RESET',
                        onPressed: () {
                          GlobalTimer.resetTimer();
                        },
                        context: context,
                      ),
                    ),

                    SizedBox(height: 15),

                    // NEU Button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: AppWidgets.menuButton(
                        text: 'NEU',
                        onPressed: () {
                          GlobalTimer.newTimer();
                        },
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Zurück Button
            Padding(
              padding: EdgeInsets.all(10),
              child: AppWidgets.pawBackButton(
                onPressed: () => Navigator.pop(context),
                isBackButton: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }
}
//#endregion

//#region PomodoroScreen
class PomodoroScreen extends StatefulWidget {
  @override
  _PomodoroScreenState createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  bool _themeLoaded = false;
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _setupPomodoroCallbacks();
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();
    setState(() {
      _themeLoaded = true;
    });
  }

  void _setupPomodoroCallbacks() {
    GlobalPomodoroTimer.setCallbacks(
      onUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
      onFinished: () {
        if (mounted) {
          setState(() {});
        }
      },
      onPhaseChange: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _startRepeating(VoidCallback action) {
    action();
    _repeatTimer = Timer.periodic(Duration(milliseconds: 150), (timer) {
      action();
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  Widget _buildTimeInput(String label, int currentValue, VoidCallback onTap) {
    return Container(
      width: ResponsiveHelper.getMaxWidth(context) - 40,
      margin: EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppStyles.labelStyle(context).copyWith(
              fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.1,
            ),
          ),
          SizedBox(height: 5),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: ResponsiveHelper.getMenuButtonHeight(context) * 1.3,
              decoration: BoxDecoration(
                color: AppTheme.colors.mainBackground2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${currentValue.toString().padLeft(2, '0')}:00',
                  style: AppStyles.fieldStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getTitleFontSize(context) * 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterInput(String label, int currentValue, Function(int) onChanged, {int min = 1, int max = 10}) {
    return Container(
      width: ResponsiveHelper.getMaxWidth(context) - 40,
      margin: EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppStyles.labelStyle(context).copyWith(
              fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.1,
            ),
          ),
          SizedBox(height: 5),
          Container(
            height: ResponsiveHelper.getMenuButtonHeight(context) * 1.3,
            decoration: BoxDecoration(
              color: AppTheme.colors.mainBackground2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: currentValue > min ? () => onChanged(currentValue - 1) : null,
                  onLongPressStart: currentValue > min ? (_) => _startRepeating(() {
                    if (currentValue > min) onChanged(currentValue - 1);
                  }) : null,
                  onLongPressEnd: (_) => _stopRepeating(),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.remove,
                      color: currentValue > min ? AppTheme.colors.mainTextColor : AppTheme.colors.mainTextColor.withOpacity(0.3),
                      size: ResponsiveHelper.getLabelFontSize(context) * 1.2,
                    ),
                  ),
                ),
                Text(
                  '${currentValue}',
                  style: AppStyles.fieldStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getTitleFontSize(context) * 1.0,
                  ),
                ),
                GestureDetector(
                  onTap: currentValue < max ? () => onChanged(currentValue + 1) : null,
                  onLongPressStart: currentValue < max ? (_) => _startRepeating(() {
                    if (currentValue < max) onChanged(currentValue + 1);
                  }) : null,
                  onLongPressEnd: (_) => _stopRepeating(),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.add,
                      color: currentValue < max ? AppTheme.colors.mainTextColor : AppTheme.colors.mainTextColor.withOpacity(0.3),
                      size: ResponsiveHelper.getLabelFontSize(context) * 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeSetDialog(String title, int currentMinutes, Function(int) onSet) {
    if (GlobalPomodoroTimer.isRunning) return;

    int tempMinutes = currentMinutes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.colors.mainBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                title,
                style: AppStyles.labelStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              content: Container(
                height: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MINUTEN',
                      style: AppStyles.labelStyle(context).copyWith(
                        fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              tempMinutes = tempMinutes > 1 ? tempMinutes - 1 : 1;
                            });
                          },
                          onLongPressStart: (_) => _startRepeating(() {
                            setDialogState(() {
                              tempMinutes = tempMinutes > 1 ? tempMinutes - 1 : 1;
                            });
                          }),
                          onLongPressEnd: (_) => _stopRepeating(),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.remove, color: AppTheme.colors.mainTextColor),
                          ),
                        ),
                        Container(
                          width: 60,
                          child: Text(
                            tempMinutes.toString().padLeft(2, '0'),
                            style: AppStyles.fieldStyle(context).copyWith(fontSize: 23),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              tempMinutes = tempMinutes < 60 ? tempMinutes + 1 : 60;
                            });
                          },
                          onLongPressStart: (_) => _startRepeating(() {
                            setDialogState(() {
                              tempMinutes = tempMinutes < 60 ? tempMinutes + 1 : 60;
                            });
                          }),
                          onLongPressEnd: (_) => _stopRepeating(),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.add, color: AppTheme.colors.mainTextColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      onSet(tempMinutes);
                      Navigator.pop(context);
                    },
                    style: AppStyles.getElevatedButtonStyle(),
                    child: Text(
                      'OK',
                      style: AppStyles.buttonStyle(context),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              child: Text(
                'POMODORO',
                style: AppStyles.titleStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.8,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      SizedBox(height: 10),

                      _buildTimeInput(
                        'ARBEITSZEIT',
                        GlobalPomodoroTimer.workTimeMinutes,
                            () => _showTimeSetDialog(
                          'ARBEITSZEIT EINSTELLEN',
                          GlobalPomodoroTimer.workTimeMinutes,
                              (minutes) => setState(() {
                            GlobalPomodoroTimer.setWorkTime(minutes);
                          }),
                        ),
                      ),

                      SizedBox(height: 10),

                      _buildCounterInput(
                        'DURCHGÄNGE',
                        GlobalPomodoroTimer.totalCycles,
                            (value) => setState(() {
                          GlobalPomodoroTimer.setTotalCycles(value);
                        }),
                        min: 1,
                        max: 10,
                      ),

                      SizedBox(height: 10),

                      _buildTimeInput(
                        'KURZE PAUSE',
                        GlobalPomodoroTimer.shortBreakMinutes,
                            () => _showTimeSetDialog(
                          'KURZE PAUSE EINSTELLEN',
                          GlobalPomodoroTimer.shortBreakMinutes,
                              (minutes) => setState(() {
                            GlobalPomodoroTimer.setShortBreak(minutes);
                          }),
                        ),
                      ),

                      SizedBox(height: 10),

                      _buildTimeInput(
                        'LANGE PAUSE',
                        GlobalPomodoroTimer.longBreakMinutes,
                            () => _showTimeSetDialog(
                          'LANGE PAUSE EINSTELLEN',
                          GlobalPomodoroTimer.longBreakMinutes,
                              (minutes) => setState(() {
                            GlobalPomodoroTimer.setLongBreak(minutes);
                          }),
                        ),
                      ),

                      SizedBox(height: 10),

                      _buildCounterInput(
                        'LANGE PAUSE NACH',
                        GlobalPomodoroTimer.longBreakAfter,
                            (value) => setState(() {
                          GlobalPomodoroTimer.setLongBreakAfter(value);
                        }),
                        min: 2,
                        max: 8,
                      ),

                      SizedBox(height: 25),

                      AppWidgets.menuButton(
                        text: GlobalPomodoroTimer.isRunning ? 'PAUSE' : 'START',
                        onPressed: () {
                          GlobalPomodoroTimer.toggleTimer();
                        },
                        context: context,
                      ),

                      SizedBox(height: 15),

                      AppWidgets.menuButton(
                        text: 'RESET',
                        onPressed: () {
                          GlobalPomodoroTimer.resetTimer();
                        },
                        context: context,
                      ),

                      SizedBox(height: 15),

                      AppWidgets.menuButton(
                        text: 'NEU',
                        onPressed: () {
                          GlobalPomodoroTimer.newTimer();
                        },
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(10),
              child: AppWidgets.pawBackButton(
                onPressed: () => Navigator.pop(context),
                isBackButton: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }
}
//#endregion

//region ToDoScreen
class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  bool _themeLoaded = false;
  final TextEditingController _todoController = TextEditingController();
  List<Map<String, dynamic>> _todos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _loadTodos();
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();
    setState(() {
      _themeLoaded = true;
    });
  }

  Future<void> _loadTodos() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('🔐 Lade verschlüsselte Todos für User: ${currentUser.uid.substring(0, 8)}...');

        DocumentSnapshot todoDoc = await FirebaseFirestore.instance
            .collection('todos')
            .doc(currentUser.uid)
            .get();

        if (todoDoc.exists) {
          Map<String, dynamic> todoData = todoDoc.data() as Map<String, dynamic>;
          List<dynamic> todoList = todoData['todoList'] ?? [];
          bool isEncrypted = todoData['encrypted'] ?? false;

          setState(() {
            if (isEncrypted && todoList.isNotEmpty) {
              // 🔐 ENTSCHLÜSSELTE TODOS LADEN
              _todos = EncryptionHelper.decryptTodos(todoList, currentUser.uid);
              print('✅ ${_todos.length} verschlüsselte Todos entschlüsselt');
            } else {
              // Legacy: Unverschlüsselte Todos (Backward Compatibility)
              _todos = todoList.map((todo) => {
                'id': todo['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                'text': todo['text'] ?? '',
                'completed': todo['completed'] ?? false,
                'createdAt': todo['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
              }).toList();
              print('⚠️ ${_todos.length} unverschlüsselte Todos geladen (Legacy)');
            }
            _isLoading = false;
          });
        } else {
          // Dokument existiert nicht, erstelle es VERSCHLÜSSELT
          await FirebaseFirestore.instance
              .collection('todos')
              .doc(currentUser.uid)
              .set({
            'todoList': [],
            'encrypted': true, // 🔐 MARKIERUNG FÜR VERSCHLÜSSELUNG
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          setState(() {
            _todos = [];
            _isLoading = false;
          });
          print('✅ Neues verschlüsseltes Todo-Dokument erstellt');
        }
      }
    } catch (e) {
      print('❌ Fehler beim Laden der Todos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTodos() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('🔐 Speichere ${_todos.length} Todos verschlüsselt...');

        // 🔐 TODOS VERSCHLÜSSELN VOR DEM SPEICHERN
        List<Map<String, dynamic>> encryptedTodos = EncryptionHelper.encryptTodos(_todos, currentUser.uid);

        await FirebaseFirestore.instance
            .collection('todos')
            .doc(currentUser.uid)
            .update({
          'todoList': encryptedTodos,
          'encrypted': true, // 🔐 MARKIERUNG FÜR VERSCHLÜSSELUNG
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('✅ Todos erfolgreich verschlüsselt und gespeichert');
      }
    } catch (e) {
      print('❌ Fehler beim Speichern der Todos: $e');
    }
  }

  void _addTodo() {
    String todoText = _todoController.text.trim();
    if (todoText.isNotEmpty && todoText.length <= 50) {
      setState(() {
        _todos.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'text': todoText,
          'completed': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      });
      _todoController.clear();
      _saveTodos();
      print('🔐 Neues Todo hinzugefügt und verschlüsselt: "${todoText.length > 10 ? todoText.substring(0, 10) + "..." : todoText}"');
    } else if (todoText.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximale Länge: 50 Zeichen'),
          backgroundColor: AppTheme.colors.mainBackground2,
        ),
      );
    }
  }

  void _removeTodo(String todoId) {
    setState(() {
      _todos.removeWhere((todo) => todo['id'] == todoId);
    });
    _saveTodos();
    print('🔐 Todo gelöscht und Liste neu verschlüsselt');
  }

  void _toggleTodo(String todoId) {
    setState(() {
      int index = _todos.indexWhere((todo) => todo['id'] == todoId);
      if (index != -1) {
        _todos[index]['completed'] = !_todos[index]['completed'];
      }
    });
    _saveTodos();
    print('🔐 Todo-Status geändert und neu verschlüsselt');
  }

  Widget _buildTodoItem(Map<String, dynamic> todo) {
    bool isCompleted = todo['completed'] ?? false;
    String todoText = todo['text'] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40, vertical: 5),
      child: Row(
        children: [
          // Todo Text (klickbar)
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleTodo(todo['id']),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.colors.mainBackground2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  todoText,
                  style: AppStyles.fieldStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.0,
                    color: isCompleted
                        ? AppTheme.colors.mainBackground
                        : AppTheme.colors.mainTextColor,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppTheme.colors.mainBackground,
                    decorationThickness: 2,
                  ),
                  maxLines: null, // Erlaubt mehrzeilige Darstellung
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),

          SizedBox(width: 10),

          // Löschen Button
          GestureDetector(
            onTap: () => _removeTodo(todo['id']),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppTheme.colors.mainBackground2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.remove,
                  color: AppTheme.colors.mainTextColor,
                  size: ResponsiveHelper.getLabelFontSize(context) * 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header mit 🔐 Security Icon
            Container(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'TODO-LISTE',
                    style: AppStyles.titleStyle(context).copyWith(
                      fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),

            // Input Bereich
            Container(
              margin: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Row(
                children: [
                  // Text Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _todoController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          hintText: 'Neue Aufgabe eingeben...',
                          hintStyle: AppStyles.fieldStyle(context).copyWith(
                            color: AppTheme.colors.mainTextColor.withOpacity(0.6),
                            fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          counterText: '',
                        ),
                        style: AppStyles.fieldStyle(context).copyWith(
                          color: AppTheme.colors.mainTextColor,
                          fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                        ),
                        onSubmitted: (_) => _addTodo(),
                      ),
                    ),
                  ),

                  SizedBox(width: 10),

                  // Add Button
                  GestureDetector(
                    onTap: _addTodo,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: AppTheme.colors.mainBackground2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: AppTheme.colors.mainTextColor,
                          size: ResponsiveHelper.getLabelFontSize(context) * 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Todo Liste
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _todos.isEmpty
                  ? Center(
                child: Text(
                  'Füge deine erste Aufgabe hinzu! 🐾',
                  style: AppStyles.labelStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: _todos.length,
                itemBuilder: (context, index) {
                  // Sortiere Todos: unerledigte zuerst, dann erledigte
                  List<Map<String, dynamic>> sortedTodos = List.from(_todos);
                  sortedTodos.sort((a, b) {
                    bool aCompleted = a['completed'] ?? false;
                    bool bCompleted = b['completed'] ?? false;
                    if (aCompleted == bCompleted) {
                      // Bei gleichem Status: nach Erstellungsdatum sortieren
                      return (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0);
                    }
                    return aCompleted ? 1 : -1; // Unerledigte zuerst
                  });

                  return _buildTodoItem(sortedTodos[index]);
                },
              ),
            ),

            // Zurück Button
            Padding(
              padding: EdgeInsets.all(10),
              child: AppWidgets.pawBackButton(
                onPressed: () => Navigator.pop(context),
                isBackButton: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }
}
//endregion

//region NotesScreen
class NotesScreen extends StatefulWidget {
  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _themeLoaded = false;
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String? _editingNoteId; // Für Bearbeitung

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _loadNotes();
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();
    setState(() {
      _themeLoaded = true;
    });
  }

  Future<void> _loadNotes() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('🔐 Lade verschlüsselte Notizen für User: ${currentUser.uid.substring(0, 8)}...');

        DocumentSnapshot notesDoc = await FirebaseFirestore.instance
            .collection('notes')
            .doc(currentUser.uid)
            .get();

        if (notesDoc.exists) {
          Map<String, dynamic> notesData = notesDoc.data() as Map<String, dynamic>;
          List<dynamic> notesList = notesData['noteList'] ?? [];
          bool isEncrypted = notesData['encrypted'] ?? false;

          setState(() {
            if (isEncrypted && notesList.isNotEmpty) {
              // 🔐 ENTSCHLÜSSELTE NOTIZEN LADEN
              _notes = EncryptionHelper.decryptNotes(notesList, currentUser.uid);
              print('✅ ${_notes.length} verschlüsselte Notizen entschlüsselt');
            } else {
              // Legacy: Unverschlüsselte Notizen (Backward Compatibility)
              _notes = notesList.map((note) => {
                'id': note['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                'title': note['title'] ?? 'Ohne Titel',
                'content': note['content'] ?? '',
                'createdAt': note['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
              }).toList();
              print('⚠️ ${_notes.length} unverschlüsselte Notizen geladen (Legacy)');
            }
            _isLoading = false;
          });
        } else {
          // Dokument existiert nicht, erstelle es VERSCHLÜSSELT
          await FirebaseFirestore.instance
              .collection('notes')
              .doc(currentUser.uid)
              .set({
            'noteList': [],
            'encrypted': true, // 🔐 MARKIERUNG FÜR VERSCHLÜSSELUNG
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          setState(() {
            _notes = [];
            _isLoading = false;
          });
          print('✅ Neues verschlüsseltes Notes-Dokument erstellt');
        }
      }
    } catch (e) {
      print('❌ Fehler beim Laden der Notizen: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('🔐 Speichere ${_notes.length} Notizen verschlüsselt...');

        // 🔐 NOTIZEN VERSCHLÜSSELN VOR DEM SPEICHERN
        List<Map<String, dynamic>> encryptedNotes = EncryptionHelper.encryptNotes(_notes, currentUser.uid);

        await FirebaseFirestore.instance
            .collection('notes')
            .doc(currentUser.uid)
            .update({
          'noteList': encryptedNotes,
          'encrypted': true, // 🔐 MARKIERUNG FÜR VERSCHLÜSSELUNG
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('✅ Notizen erfolgreich verschlüsselt und gespeichert');
      }
    } catch (e) {
      print('❌ Fehler beim Speichern der Notizen: $e');
    }
  }

  String _extractTitle(String content) {
    if (content.trim().isEmpty) return 'Ohne Titel';

    String firstLine = content.split('\n')[0].trim();
    if (firstLine.isEmpty) return 'Ohne Titel';

    return firstLine.length > 20
        ? '${firstLine.substring(0, 20)}...'
        : firstLine;
  }

  void _saveNote() {
    String noteContent = _notesController.text.trim();
    if (noteContent.isNotEmpty) {
      String title = _extractTitle(noteContent);

      if (_editingNoteId != null) {
        // Bearbeitung einer bestehenden Notiz
        setState(() {
          int index = _notes.indexWhere((note) => note['id'] == _editingNoteId);
          if (index != -1) {
            _notes[index]['title'] = title;
            _notes[index]['content'] = noteContent;
          }
          _editingNoteId = null;
        });
        print('🔐 Notiz bearbeitet und neu verschlüsselt: "${title}"');
      } else {
        // Neue Notiz
        setState(() {
          _notes.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'title': title,
            'content': noteContent,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        });
        print('🔐 Neue Notiz hinzugefügt und verschlüsselt: "${title}"');
      }

      _notesController.clear();
      _saveNotes();
    }
  }

  void _loadNote(String noteId) {
    Map<String, dynamic>? note = _notes.firstWhere(
          (note) => note['id'] == noteId,
      orElse: () => {},
    );

    if (note.isNotEmpty) {
      setState(() {
        _notesController.text = note['content'] ?? '';
        _editingNoteId = noteId;
      });
      print('🔐 Notiz zum Bearbeiten geladen: "${note['title']}"');
    }
  }

  void _deleteNote(String noteId) {
    setState(() {
      _notes.removeWhere((note) => note['id'] == noteId);
      // Falls die gerade bearbeitete Notiz gelöscht wird
      if (_editingNoteId == noteId) {
        _notesController.clear();
        _editingNoteId = null;
      }
    });
    _saveNotes();
    print('🔐 Notiz gelöscht und Liste neu verschlüsselt');
  }

  void _clearEditor() {
    setState(() {
      _notesController.clear();
      _editingNoteId = null;
    });
  }

  Widget _buildNoteItem(Map<String, dynamic> note) {
    String title = note['title'] ?? 'Ohne Titel';
    String noteId = note['id'];
    bool isEditing = _editingNoteId == noteId;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40, vertical: 5),
      child: Row(
        children: [
          // Note Title (klickbar)
          Expanded(
            child: GestureDetector(
              onTap: () => _loadNote(noteId),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: isEditing
                      ? AppTheme.colors.mainBackground2
                      : AppTheme.colors.mainBackground2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  title,
                  style: AppStyles.fieldStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.0,
                    color: isEditing
                        ? AppTheme.colors.mainBackground
                        : AppTheme.colors.mainTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          SizedBox(width: 10),

          // Löschen Button
          GestureDetector(
            onTap: () => _deleteNote(noteId),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppTheme.colors.mainBackground2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.remove,
                  color: AppTheme.colors.mainTextColor,
                  size: ResponsiveHelper.getLabelFontSize(context) * 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NOTIZEN',
                    style: AppStyles.titleStyle(context).copyWith(
                      fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),

            // Text Editor Bereich - KLEINER UND SCROLLBAR
            Container(
              margin: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              height: MediaQuery.of(context).size.height * 0.12,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Scrollbar(
                child: TextField(
                  controller: _notesController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: _editingNoteId != null
                        ? 'Notiz bearbeiten...'
                        : 'Neue Notiz eingeben...',
                    hintStyle: AppStyles.fieldStyle(context).copyWith(
                      color: AppTheme.colors.mainTextColor.withOpacity(0.6),
                      fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                  ),
                  style: AppStyles.fieldStyle(context).copyWith(
                    color: AppTheme.colors.mainTextColor,
                    fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.9,
                  ),
                ),
              ),
            ),


            Container(
              margin: EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  // Speichern Button
                  AppWidgets.menuButton(
                    text: _editingNoteId != null ? 'AKTUALISIEREN' : 'SPEICHERN',
                    onPressed: _saveNote,
                    context: context,
                  ),

                  // NEU Button (nur wenn bearbeitet wird)
                  if (_editingNoteId != null) ...[
                    SizedBox(height: 15),
                    AppWidgets.menuButton(
                      text: 'NEU',
                      onPressed: _clearEditor,
                      context: context,
                    ),
                  ],
                ],
              ),
            ),

            // Trennlinie
            Container(
              margin: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              height: 2,
              decoration: BoxDecoration(
                color: AppTheme.colors.mainTextColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),

            // Notizen Liste
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _notes.isEmpty
                  ? Center(
                child: Text(
                  'Schreibe deine erste Notiz! 🐾',
                  style: AppStyles.labelStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  // Sortiere Notizen: neueste zuerst
                  List<Map<String, dynamic>> sortedNotes = List.from(_notes);
                  sortedNotes.sort((a, b) {
                    return (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0);
                  });

                  return _buildNoteItem(sortedNotes[index]);
                },
              ),
            ),

            // Zurück Button
            Padding(
              padding: EdgeInsets.all(10),
              child: AppWidgets.pawBackButton(
                onPressed: () => Navigator.pop(context),
                isBackButton: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
//endregion

//#region InfoScreen
class InfoScreen extends StatefulWidget {
  final bool showAsWelcome; // Für Welcome-Dialog nach Registrierung

  const InfoScreen({Key? key, this.showAsWelcome = false}) : super(key: key);

  @override
  _InfoScreenState createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();
    setState(() {
      _themeLoaded = true;
    });
  }

  Widget _buildInfoSection(String title, String content, {Widget? image}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.colors.mainBackground2,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null) ...[
            Center(child: image),
            SizedBox(height: 15),
          ],
          Text(
            title,
            style: AppStyles.labelStyle(context).copyWith(
              fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            content,
            style: AppStyles.fieldStyle(context).copyWith(
              fontSize: ResponsiveHelper.getFieldFontSize(context) * 0.9,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Als Welcome Dialog nach Registrierung
    if (widget.showAsWelcome) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: ResponsiveHelper.getMaxWidth(context),
          ),
          decoration: BoxDecoration(
            color: AppTheme.colors.mainBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                child: Text(
                  'WILLKOMMEN BEI helpingPaw! 🐾',
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Scrollbarer Inhalt
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildInfoSection(
                        'DEINE PERSÖNLICHEN HELFENDEN PFOTEN',
                        'Mimi und Mr. Plum sind deine treuen Begleiter in der App!\n\n'
                            'Mimi behält immer deine laufende Timer im Auge, damit auch ja alles richtig abläuft.\n\n'
                            'Mr. Plum meldet sich, wenn deine Timer abgelaufen sind, deine Zeitphasen wechseln oder wenn es sonst etwas zu sagen gibt.',
                        image: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Image.asset('assets/images/plumSit.png', width: 80, height: 80),
                                Text('Mr. Plum', style: AppStyles.fieldStyle(context)),
                              ],
                            ),
                            Column(
                              children: [
                                Transform.scale(
                                  scaleX: -1,
                                  child: Image.asset('assets/images/mimiSit.png', width: 80, height: 80),
                                ),
                                Text('Mimi', style: AppStyles.fieldStyle(context)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      _buildInfoSection(
                        'WAS IST EIN POMODORO-TIMER?',
                        'Die Pomodoro-Technik ist eine bewährte Methode für produktives Arbeiten:\n\n'
                            '• Arbeite 25 Minuten konzentriert\n'
                            '• Mache dann 5 Minuten Pause\n'
                            '• Nach 4 Arbeitsblöcken: 15-30 Min. lange Pause\n\n'
                            'Diese Technik hilft dir dabei, fokussiert zu bleiben und Überforderung zu vermeiden!\n'
                            'Du kannst dir die Zeiten allerdings gerne einstellen wie du sie brauchst.',
                      ),

                      _buildInfoSection(
                        'AKTUELLE INFOS',
                        '📱 Die App befindet sich noch in der Entwicklung\n\n'
                            '🔜 Kommende Features:\n'
                            '• Erinnerungen\n'
                            '• Kalender-Integration\n'
                            '• Weitere Anpassungsmöglichkeiten\n\n'
                            '🔐 Deine Daten sind verschlüsselt und sicher!\n\n'
                            'Vielen Dank fürs Testen! 🐾',
                      ),
                    ],
                  ),
                ),
              ),

              // Schließen Button
              Padding(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppStyles.getElevatedButtonStyle(),
                    child: Text(
                      'LOS GEHT\'S! 🚀',
                      style: AppStyles.buttonStyle(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Als normaler Screen
    return Scaffold(
      backgroundColor: AppTheme.colors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(10),
              child: Text(
                'INFORMATIONEN',
                style: AppStyles.titleStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 1.8,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Scrollbarer Inhalt
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 10),

                    _buildInfoSection(
                      'DEINE PERSÖNLICHEN HELFENDEN PFOTEN',
                      'Mimi und Mr. Plum sind deine treuen Begleiter in der App!\n\n'
                          'Mimi behält immer deine laufende Timer im Auge, damit auch ja alles richtig abläuft.\n\n'
                          'Mr. Plum meldet sich, wenn deine Timer abgelaufen sind, deine Zeitphasen wechseln oder wenn es sonst etwas zu sagen gibt.',
                      image: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Image.asset('assets/images/plumSit.png', width: 120, height: 120),
                              Text('Mr. Plum', style: AppStyles.fieldStyle(context)),
                            ],
                          ),
                          Column(
                            children: [
                              Transform.scale(
                                scaleX: -1,
                                child: Image.asset('assets/images/mimiSit.png', width: 120, height: 120),
                              ),
                              Text('Mimi', style: AppStyles.fieldStyle(context)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    _buildInfoSection(
                      'WAS IST EIN POMODORO-TIMER?',
                      'Die Pomodoro-Technik ist eine bewährte Methode für produktives Arbeiten:\n\n'
                          '• Arbeite 25 Minuten konzentriert\n'
                          '• Mache dann 5 Minuten Pause\n'
                          '• Nach 4 Arbeitsblöcken: 15-30 Min. lange Pause\n\n'
                          'Diese Technik hilft dir dabei, fokussiert zu bleiben und Überforderung zu vermeiden!\n'
                          'Du kannst dir die Zeiten allerdings gerne einstellen wie du sie brauchst.',
                    ),

                    _buildInfoSection(
                      'FEATURES DER APP',
                      '⏰ Timer & Pomodoro-Timer\n'
                          '📝 Verschlüsselte Todo-Listen\n'
                          '📄 Sichere Notizen\n'
                          '🎨 6 verschiedene Themes\n'
                          '🔔 Benachrichtigungen\n'
                          '📱 Responsive Design\n\n'
                          'Alle deine Daten werden lokal verschlüsselt gespeichert!',
                    ),

                    _buildInfoSection(
                      'AKTUELLE INFOS & UPDATES',
                      '📱 Die App befindet sich noch in der Entwicklung\n\n'
                          '🔜 Kommende Features:\n'
                          '• Erinnerungen\n'
                          '• Kalender-Integration\n'
                          '• Weitere Anpassungsmöglichkeiten\n'
                          '• Statistiken & Fortschrittsverfolgung\n\n'
                          '🔐 Deine Privatsphäre ist uns wichtig!\n\n'
                          'Vielen Dank fürs Nutzen von helpingPaw! 🐾',
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Zurück Button
            Padding(
              padding: EdgeInsets.all(10),
              child: AppWidgets.pawBackButton(
                onPressed: () => Navigator.pop(context),
                isBackButton: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Hilfsfunktion für Welcome Dialog
void showWelcomeDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // User muss explizit schließen
    builder: (BuildContext context) {
      return InfoScreen(showAsWelcome: true);
    },
  );
}
//#endregion