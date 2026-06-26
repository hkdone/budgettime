import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';

/// Centre le contenu et limite sa largeur sur grand écran.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool center;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.pageMaxWidth,
    this.padding,
    this.center = true,
  });

  const ResponsiveContent.form({
    super.key,
    required this.child,
    this.padding,
    this.center = true,
  }) : maxWidth = Breakpoints.formMaxWidth;

  const ResponsiveContent.settings({
    super.key,
    required this.child,
    this.padding,
    this.center = true,
  }) : maxWidth = Breakpoints.settingsMaxWidth;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (!center) {
      return Align(alignment: Alignment.topCenter, child: content);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

/// Hauteur de graphique selon la largeur disponible (parent ou écran).
double chartHeightForWidth(double width) {
  if (width >= Breakpoints.expanded) return 240;
  if (width >= Breakpoints.compact) return 200;
  return 160;
}

double chartBarWidthForWidth(double width) {
  if (width >= Breakpoints.expanded) return 18;
  if (width >= Breakpoints.compact) return 14;
  return 10;
}
