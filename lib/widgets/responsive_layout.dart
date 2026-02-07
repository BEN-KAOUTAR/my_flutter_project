import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 1100;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100 &&
      MediaQuery.of(context).size.width < 1400;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1400;

  static double respSize(BuildContext context, double mobile, double tablet, double desktop) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1400) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 1100) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}
