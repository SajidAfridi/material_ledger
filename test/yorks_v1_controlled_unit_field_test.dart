import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/materials/presentation/screens/yorks_v1_controlled_unit_field.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/yorks_v1_configuration_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('controlled unit picker fails closed and retries', (
    tester,
  ) async {
    var loadCount = 0;
    await _pumpField(
      tester,
      value: '',
      units: (ref) async {
        loadCount += 1;
        throw StateError('Configuration unavailable');
      },
    );

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      _dropdownFinder(),
    );
    expect(dropdown.onChanged, isNull);
    expect(
      find.textContaining('Controlled units are unavailable.'),
      findsWidgets,
    );
    expect(find.text('Nos'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('controlled-units-retry')));
    await tester.pumpAndSettle();
    expect(loadCount, 2);
  });

  testWidgets('picker preserves persisted value without fabricating choices', (
    tester,
  ) async {
    await _pumpField(
      tester,
      value: 'Legacy crate',
      units: (ref) async => const ['Meter', 'Set'],
    );

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      _dropdownFinder(),
    );
    final menu = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('test-controlled-unit')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(dropdown.initialValue, 'Legacy crate');
    expect(dropdown.onChanged, isNotNull);
    expect(
      menu.items!.map((item) => item.value),
      containsAllInOrder(const ['Legacy crate', 'Meter', 'Set']),
    );
    expect(menu.items!.map((item) => item.value), isNot(contains('Nos')));
  });

  testWidgets('typing a unit prefix cycles matching controlled units', (
    tester,
  ) async {
    final selected = <String>[];
    await _pumpField(
      tester,
      value: '',
      units: (ref) async => const ['Bundle', 'Box', 'Bag', 'Meter'],
      onChanged: selected.add,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(selected.last, 'Bundle');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(selected.last, 'Box');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(selected.last, 'Bundle');
  });
}

Finder _dropdownFinder() => find.descendant(
  of: find.byKey(const ValueKey('test-controlled-unit')),
  matching: find.byType(DropdownButtonFormField<String>),
);

Future<void> _pumpField(
  WidgetTester tester, {
  required String value,
  required Future<List<String>> Function(Ref ref) units,
  ValueChanged<String>? onChanged,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        yorksV1ConfigurationUnitCodesProvider.overrideWith(units),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: YorksV1ControlledUnitDropdown(
            fieldKey: const ValueKey('test-controlled-unit'),
            label: 'Unit',
            value: value,
            enabled: true,
            showDependencyStatus: true,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
