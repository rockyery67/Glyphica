import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

class OutputService {
  static Uint8List encode(String text) => Uint8List.fromList(utf8.encode(text));
  static String filename(String name, {String suffix = ''}) {
    var base = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
    base = base.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    base = String.fromCharCodes(base.runes.take(70))
        .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    if (base.isEmpty) base = 'glyphica-artwork';
    if (RegExp(
      r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$',
      caseSensitive: false,
    ).hasMatch(base)) {
      base = 'art-$base';
    }
    return '$base$suffix.txt';
  }

  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  Future<Uri?> export(String name, String text) => FilePicker.saveFile(
    fileName: filename(name),
    bytes: encode(text),
    mimeType: 'text/plain',
    dialogTitle: 'Save UTF-8 artwork',
    type: FileType.custom,
    allowedExtensions: ['txt'],
  );

  Rect origin(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<ShareResult> shareText(BuildContext context, String text) =>
      SharePlus.instance.share(
        ShareParams(
          text: text,
          title: 'Share text art',
          sharePositionOrigin: origin(context),
        ),
      );

  Future<ShareResult> shareFile(
    BuildContext context,
    String name,
    String text,
  ) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(encode(text), mimeType: 'text/plain')],
      fileNameOverrides: [filename(name)],
      title: 'Share .txt artwork',
      sharePositionOrigin: origin(context),
    ),
  );
}
