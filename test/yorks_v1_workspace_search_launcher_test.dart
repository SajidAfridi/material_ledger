import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/app/yorks_v1_workspace_search_launcher.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/app_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_shell_strings.dart';

void main() {
  testWidgets(
    'Repeated search activation opens only one dialog through loading and display',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final loaded = Completer<void>();
      final closed = Completer<void>();
      var presentations = 0;
      final launcher = YorksV1WorkspaceSearchLauncher(
        load: () => loaded.future,
        present: (_, targets, language, role) {
          presentations++;
          return closed.future;
        },
      );
      Future<void> open() => launcher.open(
        context,
        targets: [],
        language: AppLanguage.english,
        role: null,
      );
      final first = open();
      await open();
      loaded.complete();
      await tester.pump();
      await open();
      expect(presentations, 1);
      closed.complete();
      await first;
      await open();
      expect(presentations, 2);
    },
  );
  testWidgets('Search can reopen after its originating workspace is disposed', (
    tester,
  ) async {
    late BuildContext context;
    Widget workspace(Key key) => MaterialApp(
      key: key,
      home: Scaffold(
        body: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final pending = Completer<void>();
    var count = 0;
    final launcher = YorksV1WorkspaceSearchLauncher(
      load: () async {},
      present: (_, targets, language, role) {
        count++;
        return count == 1 ? pending.future : Future.value();
      },
    );
    await tester.pumpWidget(workspace(const ValueKey('first')));
    final previous = launcher.open(
      context,
      targets: [],
      language: AppLanguage.english,
      role: null,
    );
    await tester.pump();
    await tester.pumpWidget(workspace(const ValueKey('second')));
    await launcher.open(
      context,
      targets: [],
      language: AppLanguage.english,
      role: null,
    );
    expect(count, 2);
    pending.complete();
    await previous;
  });

  testWidgets(
    'Failed search chunk is recoverable without navigation or raw errors',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const Text('Current work');
              },
            ),
          ),
        ),
      );
      var fail = true;
      var presentations = 0;
      final launcher = YorksV1WorkspaceSearchLauncher(
        load: () async {
          if (fail) throw StateError('private transport detail');
        },
        present: (_, targets, language, role) async {
          presentations++;
        },
      );
      await launcher.open(
        context,
        targets: [],
        language: AppLanguage.english,
        role: null,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(YorksV1ShellStrings.searchUnavailable.primary),
        findsOneWidget,
      );
      expect(find.textContaining('private transport detail'), findsNothing);
      expect(find.text('Current work'), findsOneWidget);
      fail = false;
      await tester.tap(find.text(AppStrings.retry.primary));
      await tester.pumpAndSettle();
      expect(presentations, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
