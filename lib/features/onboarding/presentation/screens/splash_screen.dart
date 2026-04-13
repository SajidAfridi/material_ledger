import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';

/// Splash screen — The Architectural Ledger branding.
///
/// Full primary-blue gradient background with animated logo reveal,
/// branding text cascade, and loading indicator.
/// Auto-navigates after animations complete.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _footerController;
  late final AnimationController _progressController;

  // Logo animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glassOpacity;

  // Text animations — staggered cascade
  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _urduOpacity;

  // Footer
  late final Animation<double> _footerOpacity;
  late final Animation<double> _lineWidth;

  @override
  void initState() {
    super.initState();

    // Set status bar for blue background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0D47A1),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // ─── Logo Controller (0–800ms) ────────────────────────────
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _glassOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    // ─── Text Controller (staggered, 0–1000ms) ───────────────
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _brandOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _brandSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
          ),
        );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _urduOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
      ),
    );

    // ─── Footer Controller (0–800ms) ─────────────────────────
    _footerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _footerController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _footerController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeInOutCubic),
      ),
    );

    // ─── Progress Controller (looping) ───────────────────────
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Phase 1: Logo
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Phase 2: Text cascade
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Phase 3: Footer + progress
    _footerController.forward();
    _progressController.repeat();

    // Phase 4: Navigate to language selection after a pause
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    context.go(RoutePaths.languageSelection);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _footerController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A56DB), // primaryContainer
              Color(0xFF003FB1), // primary
              Color(0xFF002D7A), // darker primary
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Spacer to push content to center ────────
              const Spacer(flex: 3),

              // ─── Logo with glass container ───────────────
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: _buildLogo(),
              ),

              const SizedBox(height: AppSpacing.huge),

              // ─── Brand Name ──────────────────────────────
              AnimatedBuilder(
                animation: _textController,
                builder: (context, _) {
                  return FractionalTranslation(
                    translation: _brandSlide.value,
                    child: Opacity(
                      opacity: _brandOpacity.value,
                      child: Text(
                        'GodownPro',
                        style: GoogleFonts.inter(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.84,
                          height: 1.1,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // ─── Tagline ─────────────────────────────────
              AnimatedBuilder(
                animation: _textController,
                builder: (context, _) {
                  return FractionalTranslation(
                    translation: _taglineSlide.value,
                    child: Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        'THE ARCHITECTURAL LEDGER',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 4.0,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // ─── Urdu tagline ────────────────────────────
              AnimatedBuilder(
                animation: _textController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _urduOpacity.value,
                    child: Text(
                      'السجل المعماري',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                  );
                },
              ),

              // ─── Spacer ─────────────────────────────────
              const Spacer(flex: 4),

              // ─── Bottom: Line + Badge ────────────────────
              AnimatedBuilder(
                animation: _footerController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _footerOpacity.value,
                    child: Column(
                      children: [
                        // Animated expanding line
                        AnimatedBuilder(
                          animation: _footerController,
                          builder: (context, _) {
                            return Container(
                              height: 2,
                              width: (size.width * 0.5) * _lineWidth.value,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.4),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: AppSpacing.xxl),

                        // Secure badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'SECURE INDUSTRIAL ENVIRONMENT',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Opacity(opacity: _glassOpacity.value, child: child);
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/logo.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.inventory_2_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
