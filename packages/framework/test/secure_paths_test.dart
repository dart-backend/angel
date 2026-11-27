import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The paths of the files of `AngelHttp.secure`, which were resolved as URIs
/// of the script, so that a Windows path, as `C:\certs\dev.pem`, failed with
/// "Cannot extract a file path from a c URI".
void main() {
  var pem = File('dev.pem').absolute.path;
  var key = File('dev.key').absolute.path;
  var scriptDir = p.dirname(Platform.script.toFilePath());

  group('resolveFilePath', () {
    test('keeps an absolute path', () {
      expect(AngelHttp.resolveFilePath(pem), pem);
    });

    test('reads the path of a file: URI', () {
      expect(
        AngelHttp.resolveFilePath(Uri.file(pem).toString()),
        p.normalize(pem),
      );
    });

    test('resolves a relative path of the directory of the script', () {
      expect(
        AngelHttp.resolveFilePath('certs/dev.pem'),
        p.join(scriptDir, 'certs', 'dev.pem'),
      );
    });

    test('reads either separator of a relative path on Windows', () {
      expect(
        AngelHttp.resolveFilePath(r'certs\dev.pem'),
        p.join(scriptDir, 'certs', 'dev.pem'),
      );
    }, skip: Platform.isWindows ? false : 'Of Windows paths');
  });

  group('AngelHttp.secure', () {
    Future<void> serves(String certificate, String privateKey) async {
      var app = Angel()..get('/', (req, res) => 'secure');
      var http = AngelHttp.secure(
        app,
        certificate,
        privateKey,
        password: 'dartdart',
      );
      var server = await http.startServer('127.0.0.1', 0);
      addTearDown(http.close);
      var client = HttpClient()..badCertificateCallback = (_, _, _) => true;
      addTearDown(() => client.close(force: true));
      var request = await client.getUrl(
        Uri.parse('https://127.0.0.1:${server.port}/'),
      );
      var response = await request.close();
      expect(await response.transform(utf8.decoder).join(), '"secure"');
    }

    test('serves of absolute paths', () => serves(pem, key));

    test('serves of paths relative to the script', () {
      // The script of a test is in a directory of its own, as a temporary
      // one; a path from it to the files is relative to it.
      String relative(String path) =>
          Platform.isWindows &&
              p.rootPrefix(path).toLowerCase() !=
                  p.rootPrefix(scriptDir).toLowerCase()
          ? path
          : p.relative(path, from: scriptDir);
      return serves(relative(pem), relative(key));
    });
  });
}
