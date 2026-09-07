import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/widgets/yorks_file_type_icon.dart';

void main() {
  testWidgets('Yorks file icons distinguish common operational formats', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              YorksFileTypeIcon(fileName: 'approval.pdf'),
              YorksFileTypeIcon(fileName: 'boq.xlsx'),
              YorksFileTypeIcon(fileName: 'method.docx'),
              YorksFileTypeIcon(fileName: 'site-photo.jpg'),
              YorksFileTypeIcon(fileName: 'layout.dwg'),
              YorksFileTypeIcon(fileName: 'evidence.zip'),
              YorksFileTypeIcon(fileName: 'unfamiliar.bin'),
            ],
          ),
        ),
      ),
    );

    for (final kind in [
      'pdf',
      'spreadsheet',
      'document',
      'image',
      'drawing',
      'archive',
      'file',
    ]) {
      expect(find.byKey(ValueKey('yorks-file-icon-$kind')), findsOneWidget);
    }
  });

  testWidgets('Yorks transfer badge remains a supporting visual cue', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: YorksFileTypeIcon(
            fileName: 'material-request.xlsx',
            badgeIcon: Icons.file_download_rounded,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('yorks-file-icon-spreadsheet')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.file_download_rounded), findsOneWidget);
  });
}
