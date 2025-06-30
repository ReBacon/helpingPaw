import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String mainFont = 'Jersey';

class ThemeColors {
  final Color mainBackground;
  final Color mainBackground2;
  final Color mainTextColor;

  const ThemeColors({
    required this.mainBackground,
    required this.mainBackground2,
    required this.mainTextColor,
  });

  static const ThemeColors defaultColors = ThemeColors(
    mainBackground: Color(0xFFC7F0EC),
    mainBackground2: Color(0xFF88D1CA),
    mainTextColor: Color(0xFF40615F),
  );
}

class AppTheme {
  static ThemeColors _colors = ThemeColors.defaultColors;
  static ThemeColors get colors => _colors;

  // Sicherer Fallback - lädt Theme ohne Firestore-Zugriff
  static void loadDefaultTheme() {
    _colors = ThemeColors.defaultColors;
  }

  // Hilfsfunktion um Farben sicher zu konvertieren
  static Color _parseColor(dynamic colorValue, Color fallback) {
    try {
      if (colorValue is int) {
        return Color(colorValue);
      } else if (colorValue is String) {
        // Falls als Hex-String gespeichert (z.B. "0xFFC7F0EC")
        if (colorValue.startsWith('0x')) {
          return Color(int.parse(colorValue));
        }
        // Falls als normale Hex-String gespeichert (z.B. "C7F0EC")
        if (colorValue.length == 6) {
          return Color(int.parse('0xFF$colorValue', radix: 16));
        }
        // Falls als vollständige Hex-String gespeichert (z.B. "FFC7F0EC")
        if (colorValue.length == 8) {
          return Color(int.parse('0x$colorValue', radix: 16));
        }
      }
    } catch (e) {
      print('Fehler beim Parsen der Farbe $colorValue: $e');
    }
    return fallback;
  }

  // Lädt Turquoise Theme - aber mit Error Handling
  static Future<void> loadTurquoiseTheme() async {
    try {
      print('🔄 Versuche Turquoise Theme zu laden...');

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('theme')
          .doc('turquoise')
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _colors = ThemeColors(
          mainBackground: _parseColor(data['background'], const Color(0xFFC7F0EC)),
          mainBackground2: _parseColor(data['background2'], const Color(0xFF88D1CA)),
          mainTextColor: _parseColor(data['textColor'], const Color(0xFF40615F)),
        );
        print('✅ Turquoise Theme erfolgreich geladen');
      } else {
        print('⚠️ Turquoise Theme Dokument nicht gefunden - verwende Default');
        _colors = ThemeColors.defaultColors;
      }
    } catch (e) {
      print('❌ Fehler beim Laden des Turquoise-Themes: $e');
      print('🔄 Verwende Default Theme als Fallback');
      _colors = ThemeColors.defaultColors;
    }
  }

  // Lädt User-Theme (nach Authentifizierung)
  // Ersetze die loadUserTheme Methode in style.dart mit dieser Version:

// Lädt User-Theme (nach Authentifizierung) - OHNE Theme-Collection-Zugriff
  static Future<void> loadUserTheme() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ Kein authentifizierter User - verwende Default Theme');
        _colors = ThemeColors.defaultColors;
        return;
      }

      print('🔄 Lade User Theme für: ${currentUser.uid}');

      // Hole User-Dokument
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? themeID = userData['themeID'];

        if (themeID != null) {
          print('🎨 User Theme ID: $themeID');

          // Verwende hardcoded Theme-Farben basierend auf themeID
          switch (themeID) {
            case 'turquoise':
              _colors = const ThemeColors(
                mainBackground: Color(0xFFC7F0EC),
                mainBackground2: Color(0xFF88D1CA),
                mainTextColor: Color(0xFF40615F),
              );
              break;
            case 'lavender':
              _colors = const ThemeColors(
                mainBackground: Color(0xFFE0D7EF),
                mainBackground2: Color(0xFFB8A6D9),
                mainTextColor: Color(0xFF483371),
              );
              break;
            case 'peach':
              _colors = const ThemeColors(
                mainBackground: Color(0xFFFFE8D6),
                mainBackground2: Color(0xFFFFCBA4),
                mainTextColor: Color(0xFF8A512E),
              );
              break;
            case 'skyblue':
              _colors = const ThemeColors(
                mainBackground: Color(0xFFD6E8F4),
                mainBackground2: Color(0xFFA4C8E9),
                mainTextColor: Color(0xFF1F4567),
              );
              break;
            case 'leaf':
              _colors = const ThemeColors(
                mainBackground: Color(0xFFD2F0CD),
                mainBackground2: Color(0xFFA3D9A1),
                mainTextColor: Color(0xFF224E23),
              );
              break;
            case 'rose':
              _colors = const ThemeColors(
                mainBackground: Color(0xFFF9E4EB),
                mainBackground2: Color(0xFFECC8D3),
                mainTextColor: Color(0xFF653144),
              );
              break;
            default:
              _colors = ThemeColors.defaultColors;
          }
          print('✅ User Theme ($themeID) erfolgreich geladen');
          return;
        }
      }

      // Fallback zu Default wenn User-Theme nicht gefunden
      print('⚠️ User Theme nicht gefunden - verwende Default Theme');
      _colors = ThemeColors.defaultColors;
    } catch (e) {
      print('❌ Fehler beim Laden des User-Themes: $e');
      print('🔄 Fallback zu Default Theme');
      _colors = ThemeColors.defaultColors;
    }
  }


  static void updateColors(ThemeColors newColors) {
    _colors = newColors;
  }
}

class ResponsiveHelper {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  static bool isMediumScreen(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= 360 && width < 600;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  static double getLogoSize(BuildContext context) {
    if (isSmallScreen(context)) return 100;
    if (isMediumScreen(context)) return 140;
    return 180;
  }

  static double getTitleFontSize(BuildContext context) {
    if (isSmallScreen(context)) return 45;
    if (isMediumScreen(context)) return 60;
    return 75;
  }

  static double getLabelFontSize(BuildContext context) {
    if (isSmallScreen(context)) return 20;
    if (isMediumScreen(context)) return 25;
    return 30;
  }

  static double getButtonFontSize(BuildContext context) {
    if (isSmallScreen(context)) return 20;
    if (isMediumScreen(context)) return 25;
    return 30;
  }

  static double getFieldFontSize(BuildContext context) {
    if (isSmallScreen(context)) return 18;
    if (isMediumScreen(context)) return 22;
    return 25;
  }

  static double getMaxWidth(BuildContext context) {
    if (isSmallScreen(context)) return 280;
    if (isMediumScreen(context)) return 320;
    return 400;
  }

  static double getButtonHeight(BuildContext context) {
    if (isSmallScreen(context)) return 48;
    if (isMediumScreen(context)) return 56;
    return 64;
  }

  // Neue Größe für Menü-Buttons
  static double getMenuButtonHeight(BuildContext context) {
    if (isSmallScreen(context)) return 50;
    if (isMediumScreen(context)) return 60;
    return 80;
  }

  static EdgeInsets getContentPadding(BuildContext context) {
    if (isSmallScreen(context)) return EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    if (isMediumScreen(context)) return EdgeInsets.symmetric(horizontal: 10, vertical: 10);
    return EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  }
}

class AppStyles {
  static TextStyle titleStyle(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getTitleFontSize(context),
      color: AppTheme.colors.mainTextColor,
      fontFamily: mainFont,
    );
  }

  static TextStyle labelStyle(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getLabelFontSize(context),
      color: AppTheme.colors.mainTextColor,
      fontFamily: mainFont,
    );
  }

  static TextStyle buttonStyle(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getButtonFontSize(context),
      fontFamily: mainFont,
    );
  }

  static TextStyle fieldStyle(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getFieldFontSize(context),
      color: AppTheme.colors.mainTextColor,
      fontFamily: mainFont,
    );
  }

  static TextStyle hintStyle(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getFieldFontSize(context),
      color: AppTheme.colors.mainBackground2,
      fontFamily: mainFont,
    );
  }

  static InputDecoration getInputDecoration(BuildContext context, String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle(context),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.colors.mainBackground2, width: 2),
      ),
      contentPadding: ResponsiveHelper.getContentPadding(context),
    );
  }

  static ButtonStyle getElevatedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.colors.mainBackground2,
      foregroundColor: AppTheme.colors.mainTextColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 0,
    );
  }

  // Neue Button-Styles für Menü-Buttons
  static ButtonStyle getMenuButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.colors.mainBackground2,
      foregroundColor: AppTheme.colors.mainTextColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 0,
    );
  }

  static BoxDecoration getErrorBoxDecoration() {
    return BoxDecoration(
      color: Colors.red[100],
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red),
    );
  }
}

// Neue Widget-Komponenten
class AppWidgets {
  /// Paw Button - für Menu-Navigation und Back-Buttons
  /// [onPressed]: Callback-Funktion wenn Button gedrückt wird
  /// [isBackButton]: Optional - wenn true, wird Icon gespiegelt für Back-Button-Look
  static Widget pawPlusButton({
    required VoidCallback onPressed,
    bool isBackButton = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        height: 70,
        child: Image.asset(
          'assets/images/pawPlus.png',
          color: AppTheme.colors.mainTextColor,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  static Widget pawBackButton({
    required VoidCallback onPressed,
    bool isBackButton = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        height: 70,
        child: Image.asset(
          'assets/images/pawBack.png',
          color: AppTheme.colors.mainTextColor,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  /// Menu Button - für die Hauptmenü-Buttons
  /// [text]: Der angezeigte Text
  /// [onPressed]: Callback-Funktion wenn Button gedrückt wird
  /// [context]: BuildContext für responsive Größen
  static Widget menuButton({
    required String text,
    required VoidCallback onPressed,
    required BuildContext context,
  }) {
    return SizedBox(
      width: ResponsiveHelper.getMaxWidth(context),
      height: ResponsiveHelper.getMenuButtonHeight(context),
      child: ElevatedButton(
        onPressed: onPressed,
        style: AppStyles.getMenuButtonStyle(),
        child: Text(
          text,
          style: AppStyles.buttonStyle(context),
        ),
      ),
    );
  }
}