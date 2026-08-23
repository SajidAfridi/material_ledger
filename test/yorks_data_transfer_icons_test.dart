import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/constants/constants.dart';

void main() {
  test('import, export and template download use distinct semantics', () {
    expect(YorksDataTransferIcons.importData, Icons.upload_file_rounded);
    expect(YorksDataTransferIcons.exportData, Icons.file_download_rounded);
    expect(
      YorksDataTransferIcons.downloadTemplate,
      Icons.download_for_offline_outlined,
    );
    expect(
      YorksDataTransferIcons.importData,
      isNot(YorksDataTransferIcons.exportData),
    );
  });
}
