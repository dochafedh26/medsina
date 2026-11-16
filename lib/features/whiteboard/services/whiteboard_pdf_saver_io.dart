import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveAndOpenPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  final file = File('${dir.path}/$safeName.pdf');
  await file.writeAsBytes(bytes, flush: true);
  await OpenFilex.open(file.path);
  return file.path;
}
