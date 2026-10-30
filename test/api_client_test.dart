import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pinepal_mobile/models/scan_record.dart';
import 'package:pinepal_mobile/services/api_client.dart';

ScanRecord makeScan({String imagePath = '/no/such/photo.jpg'}) {
  return ScanRecord(
    scanUuid: '11111111-2222-4333-8444-555555555555',
    predictedLabel: 'Crown_Rot',
    confidence: 0.91,
    secondLabel: 'Fruit_Rot',
    secondConfidence: 0.05,
    imageSource: 'Camera',
    imagePath: imagePath,
    latitude: 16.7083,
    longitude: 121.6833,
    scannedAt: DateTime(2026, 10, 18, 12, 58),
    notes: 'Block 3',
    feedback: ScanFeedback.incorrect,
    verifiedLabel: 'Fruit_Rot',
  );
}

ApiClient clientFor(MockClientHandler handler) {
  return ApiClient(
    client: MockClient(handler),
    baseUrl: () => 'http://server.test:5000',
  );
}

void main() {
  test('login sends the username and password and reads the account', () async {
    late http.Request seen;
    final api = clientFor((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'access_token': 'abc.def.ghi',
          'user': {
            'id': 7,
            'full_name': 'Juan Dela Cruz',
            'username': 'juan',
            'role': 'farmer',
          },
        }),
        200,
      );
    });

    final session = await api.login('juan', 'secret');

    expect(seen.method, 'POST');
    expect(seen.url.toString(), 'http://server.test:5000/api/mobile/login');
    expect(jsonDecode(seen.body), {'username': 'juan', 'password': 'secret'});
    expect(session.token, 'abc.def.ghi');
    expect(session.user.fullName, 'Juan Dela Cruz');
    expect(session.user.roleLabel, 'Farmer');
  });

  test('a wrong password shows the server message', () async {
    final api = clientFor(
      (_) async => http.Response(
        jsonEncode({'error': 'Invalid username or password'}),
        401,
      ),
    );

    await expectLater(
      api.login('juan', 'nope'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Invalid username or password')
            .having((e) => e.unauthorized, 'unauthorized', true)
            .having((e) => e.offline, 'offline', false),
      ),
    );
  });

  test(
    'an error page that is not JSON still gives a readable message',
    () async {
      final api = clientFor(
        (_) async => http.Response('<html>Internal error</html>', 500),
      );

      await expectLater(
        api.login('a', 'b'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'The server returned an error (500).',
          ),
        ),
      );
    },
  );

  test('no connection is reported as offline', () async {
    final api = clientFor((_) async => throw const SocketException('down'));

    await expectLater(
      api.login('a', 'b'),
      throwsA(isA<ApiException>().having((e) => e.offline, 'offline', true)),
    );
  });

  test('a server address that is not valid is explained', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: () => 'not a url',
    );

    await expectLater(
      api.ping(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'The server address is not valid.',
        ),
      ),
    );
  });

  test('register always asks for a farmer account', () async {
    late http.Request seen;
    final api = clientFor((request) async {
      seen = request;
      return http.Response(jsonEncode({'id': 1}), 201);
    });

    await api.register(
      fullName: 'Maria Santos',
      username: 'maria',
      password: 'pw',
    );

    expect(seen.url.path, '/api/auth/register');
    expect(jsonDecode(seen.body)['role'], 'farmer');
    expect(jsonDecode(seen.body)['full_name'], 'Maria Santos');
  });

  test(
    'uploadScan sends the token, the scan fields and the farm details',
    () async {
      late http.Request seen;
      final api = clientFor((request) async {
        seen = request;
        return http.Response(jsonEncode({'scan_uuid': 'x'}), 200);
      });

      await api.uploadScan(
        makeScan(),
        token: 'my-token',
        farmName: 'Bueno Farm',
        municipality: 'Echague',
      );

      expect(seen.url.toString(), 'http://server.test:5000/api/mobile/scans');
      expect(seen.headers['Authorization'], 'Bearer my-token');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));

      String field(String name, String value) =>
          'name="$name"\r\n\r\n$value\r\n';
      final body = seen.body;
      expect(
        body,
        contains(field('scan_uuid', '11111111-2222-4333-8444-555555555555')),
      );
      expect(body, contains(field('predicted_label', 'Crown_Rot')));
      expect(body, contains(field('confidence', '0.91')));
      expect(body, contains(field('municipality', 'Echague')));
      expect(body, contains(field('farm_name', 'Bueno Farm')));
      expect(body, contains(field('notes', 'Block 3')));
      expect(body, contains(field('farmer_feedback', 'incorrect')));
      expect(body, contains(field('farmer_label', 'Fruit_Rot')));
      expect(body, contains(field('scanned_at', '2026-10-18T12:58:00.000')));
    },
  );

  test('uploadScan leaves out empty fields and a photo that is gone', () async {
    late http.Request seen;
    final api = clientFor((request) async {
      seen = request;
      return http.Response('{}', 200);
    });
    final plain = ScanRecord(
      scanUuid: 'u',
      predictedLabel: 'No_Disease',
      confidence: 0.8,
      imageSource: 'Gallery',
      imagePath: '/photo/that/was/deleted.jpg',
      latitude: 0,
      longitude: 0,
      scannedAt: DateTime(2026, 10, 18),
    );

    await api.uploadScan(plain, token: 't');

    expect(seen.body, isNot(contains('name="second_label"')));
    expect(seen.body, isNot(contains('name="notes"')));
    expect(seen.body, isNot(contains('name="farmer_feedback"')));
    expect(seen.body, isNot(contains('name="image"')));
  });

  test('uploadScan attaches the photo when it exists', () async {
    final photo = File('${Directory.systemTemp.path}/pinepal_test_photo.jpg');
    await photo.writeAsString('fake-photo-bytes');
    addTearDown(() => photo.deleteSync());

    late http.Request seen;
    final api = clientFor((request) async {
      seen = request;
      return http.Response('{}', 200);
    });

    await api.uploadScan(makeScan(imagePath: photo.path), token: 't');

    expect(
      seen.body,
      contains('name="image"; filename="pinepal_test_photo.jpg"'),
    );
    expect(seen.body, contains('fake-photo-bytes'));
  });
}
