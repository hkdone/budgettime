import 'package:flutter/material.dart';

/// Breakpoints unifiés BudgetTime.
/// - compact  : téléphone (< 600)
/// - medium   : tablette / fenêtre étroite (600–1024)
/// - expanded : PC / grand écran (> 1024)
abstract class Breakpoints {
  static const double compact = 600;
  static const double expanded = 1024;

  static const double formMaxWidth = 640;
  static const double settingsMaxWidth = 640;
  static const double authMaxWidth = 440;
  static const double pageMaxWidth = 1200;
  static const double chartMaxWidth = 720;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isCompact => screenWidth < Breakpoints.compact;
  bool get isMedium =>
      screenWidth >= Breakpoints.compact && screenWidth < Breakpoints.expanded;
  bool get isExpanded => screenWidth >= Breakpoints.expanded;

  bool get isWideLayout => screenWidth >= Breakpoints.compact;
}
