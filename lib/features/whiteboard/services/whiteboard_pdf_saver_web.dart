import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

Future<String?> saveAndOpenPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final dataUri = Uri.dataFromBytes(bytes, mimeType: 'application/pdf');
  await launchUrl(dataUri, mode: LaunchMode.externalApplication);
  return '$fileName.pdf';
}
