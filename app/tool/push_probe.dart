// Proves the Mac can mint a token from the service-account key and reach
// FCM v1: sends to a token FCM cannot know and prints what it said. A 400
// INVALID_ARGUMENT / 404 UNREGISTERED about the token means auth and the
// API are fine; a 401/403 means the key or the API is not.
//   dart run tool/push_probe.dart [fcm-token]
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final home = Platform.environment['HOME']!;
  final json = jsonDecode(File('$home/.flutter_kit/flutterappbundle-service-account.json').readAsStringSync()) as Map<String, dynamic>;
  final creds = ServiceAccountCredentials.fromJson(json);
  final client = http.Client();
  final ac = await obtainAccessCredentialsViaServiceAccount(creds, ['https://www.googleapis.com/auth/firebase.messaging'], client);
  stdout.writeln('token minted as ${creds.email}, expires ${ac.accessToken.expiry}');
  final token = args.isEmpty ? 'probe-not-a-real-token' : args.first;
  final res = await client.post(
    Uri.parse('https://fcm.googleapis.com/v1/projects/${json['project_id']}/messages:send'),
    headers: {'Authorization': 'Bearer ${ac.accessToken.data}', 'Content-Type': 'application/json'},
    body: jsonEncode({
      'message': {
        'token': token,
        'notification': {'title': 'Probe · Kit', 'body': 'The Mac can push.'},
        'data': {'slug': 'kit', 'kind': 'problem'},
        'android': {'priority': 'high', 'notification': {'channel_id': 'problems', 'tag': 'problem-kit', 'sound': 'default'}},
      }
    }),
  );
  stdout.writeln('FCM ${res.statusCode}: ${res.body}');
  client.close();
}
