import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'style.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
    await AppTheme.loadTurquoiseTheme();
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
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                'helpingPaw',
                style: AppStyles.titleStyle(context).copyWith(
                  color: Color(0xFF1A2C3D),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 60),
              Container(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _emailController,
                  decoration: AppStyles.getInputDecoration(context, 'E-Mail'),
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
                  decoration: AppStyles.getInputDecoration(context, 'Passwort'),
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
                    'Anmelden',
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
                  'Noch kein Konto? Registrieren',
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
    await AppTheme.loadTurquoiseTheme();
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
        await FirebaseFirestore.instance
            .collection('user')
            .doc(userCredential.user!.uid)
            .set({
          'email': _emailController.text.trim(),
          'themeID': 'turquoise',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await AppTheme.loadUserTheme();
        Navigator.pop(context);
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
          // child: Padding(
          //   padding: EdgeInsets.only(top: 20), // Alles nach oben verschieben
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // Von center zu start geändert
              children: [
                Container(
                  width: ResponsiveHelper.getLogoSize(context),
                  height: ResponsiveHelper.getLogoSize(context),
                  child: Image.asset(
                    'assets/images/paw.png',
                    fit: BoxFit.contain,
                  ),
                ),
                Text(
                  'Registrieren',
                  style: AppStyles.titleStyle(context),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30), // Reduziert von 40 auf 30
                Container(
                  constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _emailController,
                    decoration: AppStyles.getInputDecoration(context, 'E-Mail'),
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
                    decoration: AppStyles.getInputDecoration(context, 'Passwort'),
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
                    decoration: AppStyles.getInputDecoration(context, 'Passwort bestätigen'),
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
                      'Registrieren',
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
          // ),
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

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    await AppTheme.loadUserTheme();

    // Lade die aktuelle Theme-ID des Users
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Aktualisieren des Themes: $e')),
      );
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
      body: Stack(
        children: [
          // Hintergrund - Katzenbaum
          Positioned(
            bottom: 60,
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

          // Katzen - schlafend (später dynamisch)
          Positioned(
            bottom: 140,
            left: 120,
            right: 0,
            child: Transform.scale(
              scaleX: -1,
              child: Image.asset(
                'assets/images/mimiSleep.png',
                width: 160,
                height: 160,
              ),
            ),
          ),

          Positioned(
            bottom: 338,
            left: 115,
            right: 0,
            child: Image.asset(
              'assets/images/plumSleep.png',
              width: 160,
              height: 160,
            ),
          ),

          // Pfote rechts oben - später Menübutton
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: () {
                _showMenu();
              },
              child: Container(
                width: 70,
                height: 70,
                child: Image.asset(
                  'assets/images/paw.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Bereich für Timer (später) - jetzt nur Platzhalter
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: 20,
            right: 20,
            child: Container(
              height: 100,
              // Hier wird später der Timer-Bereich sein
              // Momentan unsichtbar, nur als Platzhalter
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.colors.mainBackground,
          title: Text(
            'Menü',
            style: AppStyles.titleStyle(context).copyWith(
              fontSize: ResponsiveHelper.getLabelFontSize(context),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Theme auswählen:',
                style: AppStyles.labelStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.8,
                ),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: ['turquoise', 'dark'].contains(_selectedTheme) ? _selectedTheme : 'turquoise',
                decoration: AppStyles.getInputDecoration(context, 'Theme auswählen'),
                style: AppStyles.fieldStyle(context),
                dropdownColor: AppTheme.colors.mainBackground,
                items: <String>['turquoise', 'dark'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value == 'turquoise' ? 'Türkis (Standard)' : 'Dunkel',
                      style: AppStyles.fieldStyle(context).copyWith(
                        color: AppTheme.colors.mainTextColor,
                        fontSize: ResponsiveHelper.getFieldFontSize(context) * 0.8,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _updateUserTheme(newValue);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Schließen',
                style: AppStyles.labelStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.7,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
              },
              child: Text(
                'Ausloggen',
                style: AppStyles.labelStyle(context).copyWith(
                  fontSize: ResponsiveHelper.getLabelFontSize(context) * 0.7,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
//#endregion