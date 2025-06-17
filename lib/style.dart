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

  // Lädt immer das Turquoise Theme (für Login/Registrierung)
  static Future<void> loadTurquoiseTheme() async {
    try {
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
      }
    } catch (e) {
      print('Fehler beim Laden des Turquoise-Themes: $e');
      _colors = ThemeColors.defaultColors;
    }
  }

  // Lädt das User-spezifische Theme (nach dem Login)
  static Future<void> loadUserTheme() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await loadTurquoiseTheme();
        return;
      }

      // Hole User-Dokument
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? themeID = userData['themeID'];

        if (themeID != null) {
          // Hole Theme basierend auf themeID
          DocumentSnapshot themeDoc = await FirebaseFirestore.instance
              .collection('theme')
              .doc(themeID)
              .get();

          if (themeDoc.exists) {
            Map<String, dynamic> themeData = themeDoc.data() as Map<String, dynamic>;
            _colors = ThemeColors(
              mainBackground: _parseColor(themeData['background'], const Color(0xFFC7F0EC)),
              mainBackground2: _parseColor(themeData['background2'], const Color(0xFF88D1CA)),
              mainTextColor: _parseColor(themeData['textColor'], const Color(0xFF40615F)),
            );
            return;
          }
        }
      }

      // Fallback zu Turquoise wenn User-Theme nicht gefunden
      await loadTurquoiseTheme();
    } catch (e) {
      print('Fehler beim Laden des User-Themes: $e');
      await loadTurquoiseTheme();
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

  static BoxDecoration getErrorBoxDecoration() {
    return BoxDecoration(
      color: Colors.red[100],
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red),
    );
  }
}