import 'package:flutter/material.dart';

/// One semantic icon contract for file movement throughout Yorks.
///
/// Import moves a file from the user's device into Yorks, while export moves
/// Yorks data into a file on the user's device. Template download remains a
/// separate action so it is never confused with either data direction.
abstract final class YorksDataTransferIcons {
  static const IconData importData = Icons.upload_file_rounded;
  static const IconData exportData = Icons.file_download_rounded;
  static const IconData downloadTemplate = Icons.download_for_offline_outlined;
}
