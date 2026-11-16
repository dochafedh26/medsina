import 'dart:typed_data';

Future<String?> saveAndOpenPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError('PDF saving is not supported on this platform.');
}
