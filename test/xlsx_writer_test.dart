import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinepal_mobile/utils/xlsx_writer.dart';

// Reads the zip back (local headers only) so the test needs no zip package
Map<String, String> unzip(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final files = <String, String>{};
  var at = 0;
  while (data.getUint32(at, Endian.little) == 0x04034b50) {
    final size = data.getUint32(at + 18, Endian.little);
    final nameLength = data.getUint16(at + 26, Endian.little);
    final extra = data.getUint16(at + 28, Endian.little);
    final name = utf8.decode(bytes.sublist(at + 30, at + 30 + nameLength));
    final start = at + 30 + nameLength + extra;
    final packed = bytes.sublist(start, start + size);
    files[name] = utf8.decode(ZLibCodec(raw: true).decode(packed));
    at = start + size;
  }
  return files;
}

void main() {
  test('an xlsx with the sheet, header and escaped text', () {
    final files = unzip(
      buildXlsx(
        ['name', 'confidence'],
        [
          ['Crown & Rot <x>', 0.91],
          [null, 3],
        ],
      ),
    );
    expect(
      files.keys,
      containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/worksheets/sheet1.xml',
      ]),
    );
    final sheet = files['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('<c r="A1" t="inlineStr" s="1">'));
    expect(sheet, contains('Crown &amp; Rot &lt;x&gt;'));
    expect(sheet, contains('<c r="B2"><v>0.91</v></c>'));
    expect(sheet, contains('<c r="B3"><v>3</v></c>'));
  });
}
