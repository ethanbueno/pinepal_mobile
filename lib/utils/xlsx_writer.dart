import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// A small Excel (.xlsx) writer for the scan export: one sheet, a header row,
// then text and number cells. An .xlsx file is a zip of a few XML files, so
// this builds that zip by hand (dart:io deflates the files), with no extra
// package. Bold header, first row frozen.

String _xml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // characters XML does not allow (control codes other than tab and newline)
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

// "A", "B", ..., "Z", "AA", ...
String _column(int index) {
  var n = index + 1;
  var name = '';
  while (n > 0) {
    final rem = (n - 1) % 26;
    name = String.fromCharCode(65 + rem) + name;
    n = (n - 1) ~/ 26;
  }
  return name;
}

String _cell(Object? value, int col, int row, {bool bold = false}) {
  final ref = '${_column(col)}$row';
  final style = bold ? ' s="1"' : '';
  if (value is num && value.isFinite) {
    return '<c r="$ref"$style><v>$value</v></c>';
  }
  final text = value?.toString() ?? '';
  if (text.isEmpty) return '';
  return '<c r="$ref" t="inlineStr"$style><is><t xml:space="preserve">'
      '${_xml(text)}</t></is></c>';
}

String _sheet(List<String> headers, List<List<Object?>> rows) {
  final out = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    )
    ..write(
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" '
      'topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>',
    )
    ..write('<sheetData>')
    ..write('<row r="1">');
  for (var c = 0; c < headers.length; c++) {
    out.write(_cell(headers[c], c, 1, bold: true));
  }
  out.write('</row>');
  for (var r = 0; r < rows.length; r++) {
    out.write('<row r="${r + 2}">');
    for (var c = 0; c < rows[r].length; c++) {
      out.write(_cell(rows[r][c], c, r + 2));
    }
    out.write('</row>');
  }
  out.write('</sheetData></worksheet>');
  return out.toString();
}

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbook(String sheetName) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="${_xml(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>';

const _workbookRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

// two fonts (normal, bold) and two cell styles (0 normal, 1 bold)
const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
    '</styleSheet>';

// The .xlsx file's bytes: one sheet with the headers in bold and the rows under them
Uint8List buildXlsx(
  List<String> headers,
  List<List<Object?>> rows, {
  String sheetName = 'Scans',
}) {
  return _zip({
    '[Content_Types].xml': _contentTypes,
    '_rels/.rels': _rootRels,
    'xl/workbook.xml': _workbook(sheetName),
    'xl/_rels/workbook.xml.rels': _workbookRels,
    'xl/styles.xml': _styles,
    'xl/worksheets/sheet1.xml': _sheet(headers, rows),
  });
}

// ---- a minimal zip writer (deflate, no zip64; plenty for a scan export) ----

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

Uint8List _zip(Map<String, String> files) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  final deflate = ZLibCodec(raw: true, level: 6);

  void u16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
  void u32(BytesBuilder b, int v) =>
      b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

  for (final entry in files.entries) {
    final name = utf8.encode(entry.key);
    final data = utf8.encode(entry.value);
    final packed = deflate.encode(data);
    final crc = _crc32(data);
    final offset = out.length;

    // local file header
    u32(out, 0x04034b50);
    u16(out, 20); // version needed
    u16(out, 0x0800); // flags: UTF-8 names
    u16(out, 8); // deflate
    u16(out, 0); // time
    u16(out, 0x21); // date: 1980-01-01
    u32(out, crc);
    u32(out, packed.length);
    u32(out, data.length);
    u16(out, name.length);
    u16(out, 0);
    out.add(name);
    out.add(packed);

    // its entry in the central directory
    u32(central, 0x02014b50);
    u16(central, 20); // made by
    u16(central, 20); // version needed
    u16(central, 0x0800);
    u16(central, 8);
    u16(central, 0);
    u16(central, 0x21);
    u32(central, crc);
    u32(central, packed.length);
    u32(central, data.length);
    u16(central, name.length);
    u16(central, 0); // extra
    u16(central, 0); // comment
    u16(central, 0); // disk
    u16(central, 0); // internal attributes
    u32(central, 0); // external attributes
    u32(central, offset);
    central.add(name);
  }

  final centralStart = out.length;
  final centralBytes = central.toBytes();
  out.add(centralBytes);

  // end of central directory
  u32(out, 0x06054b50);
  u16(out, 0);
  u16(out, 0);
  u16(out, files.length);
  u16(out, files.length);
  u32(out, centralBytes.length);
  u32(out, centralStart);
  u16(out, 0);
  return out.toBytes();
}
