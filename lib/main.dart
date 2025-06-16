import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// #region Main App Entry Point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'helpingPaw',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Jersey',
      ),
      home: AuthWrapper(), // AuthWrapper prüft den Login-Status
      debugShowCheckedModeBanner: false,
    );
  }
}
// #endregion

// #region Authentication Wrapper
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
          // User ist eingeloggt
          return HomeScreen();
        } else {
          // User ist nicht eingeloggt
          return LoginScreen();
        }
      },
    );
  }
}
// #endregion

// #region Login Screen
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // #region Controllers und Variablen
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;

  // Farben
  final Color backgroundColor = Color(0xFFC7F0EC);
  final Color primaryColor = Color(0xFF40615F);
  final Color buttonColor = Color(0xFF88D1CA);
  // #endregion

  // #region Authentication Methods
  Future<void> _signInWithEmailAndPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Navigation erfolgt automatisch durch AuthWrapper
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'Benutzer nicht gefunden';
            break;
          case 'wrong-password':
            _errorMessage = 'Falsches Passwort';
            break;
          case 'invalid-email':
            _errorMessage = 'Ungültige E-Mail-Adresse';
            break;
          case 'user-disabled':
            _errorMessage = 'Benutzer wurde deaktiviert';
            break;
          case 'too-many-requests':
            _errorMessage = 'Zu viele Versuche. Bitte warten Sie.';
            break;
          default:
            _errorMessage = 'Anmeldung fehlgeschlagen: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bitte geben Sie Ihre E-Mail-Adresse ein'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwort-Reset E-Mail wurde gesendet'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Eingabe-Validierung
  bool get _isFormValid {
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _emailController.text.contains('@');
  }
  // #endregion

  // #region UI Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // #region Logo Section
                SizedBox(height: 30),
                Column(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      child: Image.asset(
                        'assets/images/paw.png',
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: buttonColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.pets,
                              size: 80,
                              color: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    Text(
                      'helpingPaw',
                      style: TextStyle(
                        fontSize: 60,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                  ],
                ),
                // #endregion

                SizedBox(height: 30),

                // #region Error Message
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 320),
                    margin: EdgeInsets.only(bottom: 20),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // #endregion

                // #region Login Form
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // #region Email Field
                      Text(
                        'E-MAIL',
                        style: TextStyle(
                          fontSize: 30,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 5),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          fontSize: 25,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'E-MAIL',
                          hintStyle: TextStyle(
                            fontSize: 25,
                            color: buttonColor,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: buttonColor, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) => setState(() {
                          _errorMessage = null;
                        }),
                      ),
                      // #endregion

                      SizedBox(height: 10),

                      // #region Password Field
                      Text(
                        'PASSWORT',
                        style: TextStyle(
                          fontSize: 30,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 5),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(
                          fontSize: 25,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'PASSWORT',
                          hintStyle: TextStyle(
                            fontSize: 25,
                            color: buttonColor,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: buttonColor, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) => setState(() {
                          _errorMessage = null;
                        }),
                      ),
                      // #endregion

                      SizedBox(height: 5),

                      // #region Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          child: Text(
                            'PASSWORT VERGESSEN?',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      // #endregion

                      SizedBox(height: 30),

                      // #region Action Buttons
                      Column(
                        children: [
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                ),
                              )
                                  : Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 30,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 10),

                          // Registrieren Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'REGISTRIEREN',
                                style: TextStyle(
                                  fontSize: 30,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 10),

                          // Beenden Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () {
                                // App beenden (nur auf mobilen Geräten)
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: primaryColor,
                                disabledBackgroundColor: buttonColor.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'BEENDEN',
                                style: TextStyle(
                                  fontSize: 30,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // #endregion
                    ],
                  ),
                ),
                // #endregion

                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // #endregion

  // #region Dispose
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
// #endregion
}
// #endregion

// #region Register Screen
class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // #region Controllers und Variablen
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;

  // Farben
  final Color backgroundColor = Color(0xFFC7F0EC);
  final Color primaryColor = Color(0xFF40615F);
  final Color buttonColor = Color(0xFF88D1CA);
  // #endregion

  // #region Registration Method
  Future<void> _registerWithEmailAndPassword() async {
    // Validierung
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwörter stimmen nicht überein';
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Passwort muss mindestens 6 Zeichen haben';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Benutzer erstellen
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Hier später Firestore-Daten speichern
      // TODO: User-Daten in Firestore speichern

      // Zurück zum Login (AuthWrapper übernimmt die Navigation)
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'weak-password':
            _errorMessage = 'Passwort ist zu schwach';
            break;
          case 'email-already-in-use':
            _errorMessage = 'E-Mail wird bereits verwendet';
            break;
          case 'invalid-email':
            _errorMessage = 'Ungültige E-Mail-Adresse';
            break;
          default:
            _errorMessage = 'Registrierung fehlgeschlagen: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  // #endregion

  // #region UI Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text('Registrierung'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 20),

                // #region Logo
                Container(
                  width: 100,
                  height: 100,
                  child: Image.asset(
                    'assets/images/paw.png',
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: buttonColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.pets,
                          size: 60,
                          color: primaryColor,
                        ),
                      );
                    },
                  ),
                ),
                // #endregion

                SizedBox(height: 30),

                // #region Error Message
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 320),
                    margin: EdgeInsets.only(bottom: 20),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // #endregion

                // #region Registration Form
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // #region Username Field
                      Text(
                        'BENUTZERNAME',
                        style: TextStyle(
                          fontSize: 30,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 5),
                      TextField(
                        controller: _usernameController,
                        style: TextStyle(
                          fontSize: 25,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'BENUTZERNAME',
                          hintStyle: TextStyle(
                            fontSize: 25,
                            color: buttonColor,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: buttonColor, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) => setState(() {
                          _errorMessage = null;
                        }),
                      ),
                      // #endregion

                      SizedBox(height: 15),

                      // #region Email Field
                      Text(
                        'E-MAIL',
                        style: TextStyle(
                          fontSize: 30,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 5),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          fontSize: 25,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'E-MAIL',
                          hintStyle: TextStyle(
                            fontSize: 25,
                            color: buttonColor,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: buttonColor, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) => setState(() {
                          _errorMessage = null;
                        }),
                      ),
                      // #endregion

                      SizedBox(height: 15),

                      // #region Password Field
                      Text(
                        'PASSWORT',
                        style: TextStyle(
                          fontSize: 30,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 5),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(
                          fontSize: 25,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'PASSWORT',
                          hintStyle: TextStyle(
                            fontSize: 25,
                            color: buttonColor,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: buttonColor, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) => setState(() {
                          _errorMessage = null;
                        }),
                      ),
                      // #endregion

                      SizedBox(height: 15),

                      // #region Confirm Password Field
                      Text(
                        'PASSWORT BESTÄTIGEN',
                        style: TextStyle(
                          fontSize: 30,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 5),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: TextStyle(
                          fontSize: 25,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'PASSWORT BESTÄTIGEN',
                          hintStyle: TextStyle(
                            fontSize: 25,
                            color: buttonColor,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: buttonColor, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) => setState(() {
                          _errorMessage = null;
                        }),
                      ),
                      // #endregion

                      SizedBox(height: 30),

                      // #region Action Buttons
                      // Registrieren Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerWithEmailAndPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          )
                              : Text(
                            'REGISTRIEREN',
                            style: TextStyle(
                              fontSize: 30,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 10),

                      // Zurück Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'ZURÜCK',
                            style: TextStyle(
                              fontSize: 30,
                            ),
                          ),
                        ),
                      ),
                      // #endregion
                    ],
                  ),
                ),
                // #endregion

                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // #endregion

  // #region Dispose
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
// #endregion
}
// #endregion

// #region Home Screen
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Color(0xFFC7F0EC),
      appBar: AppBar(
        title: Text('helpingPaw'),
        backgroundColor: Color(0xFF40615F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Willkommen!',
              style: TextStyle(
                fontSize: 32,
                color: Color(0xFF40615F),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Du bist eingeloggt als:',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF40615F),
              ),
            ),
            SizedBox(height: 10),
            Text(
              user?.email ?? 'Unbekannt',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF88D1CA),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// #endregion