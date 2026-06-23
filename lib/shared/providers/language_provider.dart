import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_currency.dart';
import '../models/app_language.dart';

const _kLanguageKey = 'selected_language';
const _kCurrencyKey = 'selected_currency';
const _kOnboardingCompleteKey = 'onboarding_complete';
const _kAuthUserIdKey = 'auth_user_id';

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

// ─── Onboarding ──────────────────────────────────────────────────

/// Whether the user has completed onboarding (language selection).
final onboardingCompleteProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return OnboardingNotifier(prefs);
    });

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._prefs)
    : super(_prefs.getBool(_kOnboardingCompleteKey) ?? false);

  final SharedPreferences _prefs;

  Future<void> complete() async {
    await _prefs.setBool(_kOnboardingCompleteKey, true);
    state = true;
  }
}

// ─── Secondary Language ──────────────────────────────────────────

/// The currently selected secondary language (Arabic by default).
final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LanguageNotifier(prefs);
});

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier(this._prefs)
    : super(
        AppLanguage.fromCode(
          _prefs.getString(_kLanguageKey) ?? AppLanguage.arabic.code,
        ),
      );

  final SharedPreferences _prefs;

  Future<void> setLanguage(AppLanguage language) async {
    await _prefs.setString(_kLanguageKey, language.code);
    state = language;
  }
}

// ─── Currency ────────────────────────────────────────────────────

/// The currently selected currency (AED by default).
final currencyProvider = StateNotifierProvider<CurrencyNotifier, AppCurrency>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CurrencyNotifier(prefs);
});

class CurrencyNotifier extends StateNotifier<AppCurrency> {
  CurrencyNotifier(this._prefs)
    : super(
        AppCurrency.fromCode(
          _prefs.getString(_kCurrencyKey) ?? AppCurrency.aed.code,
        ),
      );

  final SharedPreferences _prefs;

  Future<void> setCurrency(AppCurrency currency) async {
    await _prefs.setString(_kCurrencyKey, currency.code);
    state = currency;
  }
}

// ─── Auth Session ────────────────────────────────────────────────

/// The signed-in user's id, or `null` when logged out. Set only after
/// credentials are verified (see `authControllerProvider` in session_provider).
/// This is the seam that becomes the Firebase Auth uid.
final authSessionProvider = StateNotifierProvider<AuthSessionNotifier, String?>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthSessionNotifier(prefs);
});

/// Convenience boolean for redirect logic / widgets.
final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authSessionProvider) != null,
);

class AuthSessionNotifier extends StateNotifier<String?> {
  AuthSessionNotifier(this._prefs) : super(_prefs.getString(_kAuthUserIdKey));

  final SharedPreferences _prefs;

  Future<void> setUser(String userId) async {
    await _prefs.setString(_kAuthUserIdKey, userId);
    state = userId;
  }

  Future<void> logout() async {
    await _prefs.remove(_kAuthUserIdKey);
    state = null;
  }
}
