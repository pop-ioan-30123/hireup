import 'package:flutter/material.dart';

/// Responsive breakpoints for different device sizes
class ResponsiveBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
}

/// Helper class for responsive design
class Responsive {
  /// Get responsive value based on screen width
  static T value<T>({
    required BuildContext context,
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= ResponsiveBreakpoints.desktop) return desktop;
    if (width >= ResponsiveBreakpoints.tablet) return tablet;
    return mobile;
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.tablet;

  /// Check if device is tablet
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tablet &&
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.desktop;

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;

  /// Get responsive padding
  static EdgeInsets responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.desktop) {
      return const EdgeInsets.all(40);
    } else if (width >= ResponsiveBreakpoints.tablet) {
      return const EdgeInsets.all(30);
    }
    return const EdgeInsets.all(20);
  }

  /// Get responsive font size
  static double fontSize({
    required BuildContext context,
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    return value<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Get max width for content
  static double getContentMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.desktop) return 600;
    if (width >= ResponsiveBreakpoints.tablet) return 500;
    return double.infinity;
  }

  /// Get responsive column count for grid layouts
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.desktop) return 3;
    if (width >= ResponsiveBreakpoints.tablet) return 2;
    return 1;
  }

  /// Get device orientation
  static Orientation getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation;
  }

  /// Check if landscape
  static bool isLandscape(BuildContext context) =>
      getOrientation(context) == Orientation.landscape;

  /// Get responsive spacing
  static double spacing({
    required BuildContext context,
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    return value<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}
