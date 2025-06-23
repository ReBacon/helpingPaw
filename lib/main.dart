import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'style.dart';
import 'notification_service.dart';

//region x
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Vereinfachte Initialisierung - nur für Sound
  await NotificationService.initialize();
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
  static bool _isFinished = false; // Neu: Timer abgelaufen Status

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
      // Timer pausieren
      _timer?.cancel();
      _isRunning = false;
    } else {
      // Timer starten
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
          // Timer abgelaufen
          _timer?.cancel();
          _isRunning = false;
          _isFinished = true;

          // ✅ Nur Sound abspielen - keine komplexe Notification
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

  // Timer komplett neu (alles auf 0)
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
//endregion

//#region LoginScreen
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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

  Future<void> _login() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await AppTheme.loadUserTheme();
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login fehlgeschlagen: ${e.toString()}';
      });
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
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 20),
                Container(
                  constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(10),
                  decoration: AppStyles.getErrorBoxDecoration(),
                  child: Text(
                    _errorMessage,
                    style: AppStyles.fieldStyle(context).copyWith(color: Colors.red[800]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwörter stimmen nicht überein';
      });
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await Future.delayed(Duration(milliseconds: 500));

        try {
          Map<String, dynamic> userData = {
            'email': _emailController.text.trim(),
            'themeID': 'turquoise',
            'notificationsEnabled': true,
            'soundEnabled': true,
            'createdAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('user')
              .doc(userCredential.user!.uid)
              .set(userData);

          await AppTheme.loadUserTheme();

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomeScreen()),
                (Route<dynamic> route) => false,
          );
        } catch (firestoreError) {
          setState(() {
            _errorMessage = 'Firestore Fehler: ${firestoreError.toString()}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Registrierung fehlgeschlagen: ${e.toString()}';
      });
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
              SizedBox(height: 110),
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 20),
                Container(
                  constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(10),
                  decoration: AppStyles.getErrorBoxDecoration(),
                  child: Text(
                    _errorMessage,
                    style: AppStyles.fieldStyle(context).copyWith(color: Colors.red[800]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
  Timer? _uiUpdateTimer; // Zusätzlicher Timer für UI-Updates

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _setupTimerCallbacks();
    _startUIUpdateTimer(); // Zusätzliche UI-Update-Logik
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          _selectedTheme = userData['themeID'] ?? 'turquoise';
        }
      }
    } catch (e) {
      print('Fehler beim Laden der Theme-ID: $e');
    }

    setState(() {
      _themeLoaded = true;
    });
  }

  void _setupTimerCallbacks() {
    // Callbacks immer neu setzen wenn HomeScreen geladen wird
    GlobalTimer.setCallbacks(
      onUpdate: () {
        if (mounted) {
          setState(() {
            // Nur loggen wenn Timer läuft
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

  // Zusätzlicher UI-Update Timer für bessere Synchronisation
  void _startUIUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (mounted && GlobalTimer.isRunning) {
        // Nur aktualisieren wenn Timer läuft oder beendet ist
        setState(() {
          // UI alle 500ms aktualisieren nur wenn Timer aktiv ist
        });
      }
    });
  }

  // Plum antippen - Timer finished Status zurücksetzen
  void _onPlumTapped() {
    if (GlobalTimer.isFinished) {
      GlobalTimer.clearFinished();
      print('🐱 Plum getappt - Timer finished Status zurückgesetzt');
    }
  }

  // Timer Display Widget - HIER IST DIE WICHTIGE ÄNDERUNG
  Widget _buildTimerDisplay() {
    String displayText = GlobalTimer.getDisplayTimerText();
    bool isFinished = GlobalTimer.isFinished;
    bool isRunning = GlobalTimer.isRunning;

    // Nur loggen wenn Timer läuft (nicht wenn finished)
    if (isRunning) {
      print('🖥️ HomeScreen Timer Display: $displayText (Running: $isRunning, Finished: $isFinished)');
    }

    // Timer-Display nur anzeigen wenn Timer läuft oder beendet ist
    if (!isRunning && !isFinished) {
      return Container(); // Leerer Container = unsichtbar
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
        height: ResponsiveHelper.getMenuButtonHeight(context) * 2.5, // Gleiche Höhe wie TimerScreen
        decoration: BoxDecoration(
          color: AppTheme.colors.mainBackground2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20), // Abstand links und rechts
              child: Text(
                displayText,
                style: isFinished
                    ? AppStyles.buttonStyle(context).copyWith(  // Button-Style für "Timer abgelaufen"
                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 0.6,  // ← Noch kleiner (0.6 statt 0.8)
                  color: AppTheme.colors.mainTextColor,
                  fontWeight: FontWeight.normal,
                )
                    : AppStyles.fieldStyle(context).copyWith(  // Normal-Style für laufenden Timer
                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 1.2,
                  color: AppTheme.colors.mainTextColor,
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 3, // Erlaubt Zeilenumbruch auf 2 Zeilen
                overflow: TextOverflow.visible, // Text wird umgebrochen statt abgeschnitten
              ),
            ),
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
          // Hintergrund - Katzenbaum
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

          // Mimi Katze - reagiert auf Timer
          Positioned(
            bottom: GlobalTimer.isRunning ? 160 : 130, // Position anpassen für mimiSit
            left: GlobalTimer.isRunning ? 130 : 120, // Position anpassen für mimiSit
            right: 0,
            child: Transform.scale(
              scaleX: -1,
              child: GestureDetector(
                onTap: () {
                  print('🐱 Mimi getappt - Timer läuft: ${GlobalTimer.isRunning}');
                },
                child: Image.asset(
                  GlobalTimer.isRunning ? 'assets/images/mimiSit.png' : 'assets/images/mimiSleep.png',
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ),

          // Plum Katze - reagiert auf Timer finished
          Positioned(
            bottom: GlobalTimer.isFinished ? 360 : 328, // Position anpassen für plumSit
            left: GlobalTimer.isFinished ? 90 : 115, // Position anpassen für plumSit
            right: 0,
            child: GestureDetector(
              onTap: _onPlumTapped, // Plum antippen um Timer finished zu clearen
              child: Image.asset(
                GlobalTimer.isFinished ? 'assets/images/plumSit.png' : 'assets/images/plumSleep.png',
                width: 160,
                height: 160,
              ),
            ),
          ),

          // Pfote rechts oben (Menü)
          Positioned(
            top: 50,
            right: 20,
            child: AppWidgets.pawButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MenuScreen()),
                );
                await _loadUserTheme();
                // Callbacks nach Rückkehr neu setzen
                _setupTimerCallbacks();
              },
            ),
          ),

          // Timer Display zwischen Menü und Grafiken
          Positioned(
            top: MediaQuery.of(context).size.height * 0.17,
            left: 20,
            right: 20,
            child: _buildTimerDisplay(),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Pomodoro-Timer - Coming Soon!')),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'TODO-LISTE',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Todo-Liste - Coming Soon!')),
                          );
                        },
                        context: context,
                      ),
                      SizedBox(height: 15),
                      AppWidgets.menuButton(
                        text: 'NOTIZEN',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Notizen - Coming Soon!')),
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
              child: AppWidgets.pawButton(
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
      'background2': Color(0xFFB19CD9),
      'background': Color(0xFFE6E0F0),
      'textColor': Color(0xFF5D4E75),
    },
    'peach': {
      'background2': Color(0xFFFFB085),
      'background': Color(0xFFFFE4D6),
      'textColor': Color(0xFF8B4513),
    },
    'skyblue': {
      'background2': Color(0xFF87CEEB),
      'background': Color(0xFFE0F6FF),
      'textColor': Color(0xFF2F4F8F),
    },
    'mint': {
      'background2': Color(0xFF98FB98),
      'background': Color(0xFFE8FFE8),
      'textColor': Color(0xFF2E8B57),
    },
    'rose': {
      'background2': Color(0xFFFFB6C1),
      'background': Color(0xFFFFE4E1),
      'textColor': Color(0xFF8B4A6B),
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
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
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

  Widget _buildSettingSwitch(String title, bool value, Function(bool) onChanged) {
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
                              _buildThemePreview('mint'),
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
                          (value) => _updateUserSetting('notificationsEnabled', value),
                    ),
                    _buildSettingSwitch(
                      'TON',
                      _soundEnabled,
                          (value) => _updateUserSetting('soundEnabled', value),
                    ),
                    SizedBox(height: 30),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: AppWidgets.menuButton(
                        text: 'LOGOUT',
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).popUntil((route) => route.isFirst);
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
              child: AppWidgets.pawButton(
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
                    // Zeit-Anzeige (klickbar) - HIER IST DIE WICHTIGE ÄNDERUNG
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
                              padding: EdgeInsets.symmetric(horizontal: 20), // Abstand links und rechts
                              child: Text(
                                GlobalTimer.getDisplayTimerText(),
                                style: GlobalTimer.isFinished
                                    ? AppStyles.buttonStyle(context).copyWith(  // Button-Style für "Timer abgelaufen"
                                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 0.6,  // ← Noch kleiner (0.6 statt 0.8)
                                  color: AppTheme.colors.mainTextColor,
                                  fontWeight: FontWeight.normal,
                                )
                                    : AppStyles.fieldStyle(context).copyWith(  // Normal-Style für Timer
                                  fontSize: ResponsiveHelper.getTitleFontSize(context) * 1.2,
                                  color: AppTheme.colors.mainTextColor,
                                  fontWeight: FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3, // Erlaubt Zeilenumbruch auf 2 Zeilen
                                overflow: TextOverflow.visible, // Text wird umgebrochen statt abgeschnitten
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
              child: AppWidgets.pawButton(
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
    // NICHT GlobalTimer.dispose() - da er global bleiben soll!
    super.dispose();
  }
}
//#endregion