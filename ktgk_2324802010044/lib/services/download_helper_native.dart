import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Lưu bytes ra file rồi mở share sheet (Android / iOS / Desktop).
Future<void> triggerDownload(List<int> bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final outDir = Directory('${dir.path}/manga_downloads');
  await outDir.create(recursive: true);
  final file = File('${outDir.path}/$filename');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: filename);
}