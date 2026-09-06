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

    expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    expect(find.byIcon(Icons.table_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_rounded), findsOneWidget);
    expect(find.byIcon(Icons.image_rounded), findsOneWidget);
    expect(find.byIcon(Icons.architecture_rounded), findsOneWidget);
    expect(find.byIcon(Icons.folder_zip_rounded), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
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

    expect(find.byIcon(Icons.table_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.file_download_rounded), findsOneWidget);
  });
}
