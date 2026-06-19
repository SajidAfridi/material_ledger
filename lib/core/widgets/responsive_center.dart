import 'package:flutter/material.dart';

/// Centres its child and caps the content width on large displays (tablet/web)
/// while leaving phones unaffected (phone widths are below [maxWidth]).
///
/// Keeps the single-column reading layout comfortable on wide screens without
/// changing the look on mobile.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
