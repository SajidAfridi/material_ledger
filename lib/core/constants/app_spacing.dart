/// Yorks Nexus V7 spacing, shape and responsive layout tokens.
abstract final class AppSpacing {
  static const double unit = 4;

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
  static const double gigantic = 56;
  static const double colossal = 64;

  static const double listItemGap = md;
  static const double bilingualGap = xs;
  static const double cardPadding = xl;

  static const double screenHorizontal = 30;
  static const double screenVertical = 26;
  static const double mobileScreenHorizontal = 14;
  static const double mobileScreenVertical = 18;

  static const double radiusSm = 9;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
  static const double radiusXl = 18;
  static const double radiusFull = 999;

  static const double ambientBlur = 16;
  static const double backdropBlur = 18;

  /// Compact browser control height from the approved V7 design.
  static const double controlHeight = 38;

  /// Minimum interactive target across touch layouts.
  static const double minTapTarget = 44;

  static const double compactBreakpoint = 720;

  /// Effective R35 desktop boundary. Yorks V1 office routes retain a full
  /// navigation/worksheet layout from this width upward; narrower layouts
  /// switch to the focused tablet/mobile presentation.
  static const double yorksV1DesktopBreakpoint = 1100;
  static const double stackedBreakpoint = 980;
  static const double wideBreakpoint = 1180;
  static const double pageMaxWidth = 1740;
  static const double inspectorWidth = 330;
  static const double sidebarWidth = 246;
  static const double sidebarCollapsedWidth = 84;
  static const double topBarHeight = 64;
}
