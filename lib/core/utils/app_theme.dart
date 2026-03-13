import 'package:flutter/material.dart';

/// Semantic color constants — centralized to avoid scatter of hardcoded colors.
abstract class AppColors {
  // Semantic transaction types
  static const Color income = Color(0xFF2E7D32); // green[800]
  static const Color expense = Color(0xFFC62828); // red[800]
  static const Color transfer = Color(0xFF1565C0); // blue[800]
  static const Color warning = Color(0xFFE65100); // orange[900] — active toggle

  // Transaction card backgrounds (effective vs projected)
  static const Color effectiveCard = Color(
    0xFFEDE7F6,
  ); // deepPurple[50] — matches seed
  static const Color effectiveBorder = Color(0xFFCE93D8); // deepPurple[200]

  // Text helpers
  static const Color textSecondary = Color(0xFF757575); // grey[600]

  // Chart base colors
  static const Color chartIncome = Color(0xFF2E7D32); // green[800]
  static const Color chartExpense = Color(0xFFC62828); // red[800]
  static const Color chartMemberExpense = Color(0xFFBF360C); // deepOrange[900]

  /// Fallback palette for pie-chart slices (replaces Colors.primaries spread).
  static const List<Color> chartPalette = [
    Color(0xFF5C6BC0), // indigo
    Color(0xFF26A69A), // teal
    Color(0xFFEC407A), // pink
    Color(0xFFAB47BC), // purple
    Color(0xFF26C6DA), // cyan
    Color(0xFFFF7043), // deepOrange
    Color(0xFF66BB6A), // green
    Color(0xFFFFCA28), // amber
  ];

  /// Deterministic palette for member pie charts (replaces hashCode-based Colors.primaries).
  static const List<Color> memberPalette = [
    Color(0xFF7B1FA2), // deepPurple[700]
    Color(0xFF1565C0), // blue[800]
    Color(0xFF2E7D32), // green[800]
    Color(0xFFE65100), // orange[900]
    Color(0xFF00838F), // cyan[800]
    Color(0xFFAD1457), // pink[800]
    Color(0xFF558B2F), // lightGreen[800]
    Color(0xFF4527A0), // deepPurple[900]
  ];
}

/// Layout spacing constants — prefer these over inline pixel values.
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  static const double cardRadius = 12.0;
  static const double cardPadding = 16.0;
  static const double cardElevation = 2.0;
}
