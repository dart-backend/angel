import 'dart:async';
import 'dart:io' show HttpHeaders, HttpStatus;
import 'dart:typed_data';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
import 'package:angel_static/angel_static.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:range_header/range_header.dart';

main() async {
  var app = new Angel();
  var http = new AngelHttp(app);
  var fs = const LocalFileSystem();
  var vDir = new _RangingVirtualDirectory(app, fs.currentDirectory);
  app.logger = new Logger('range_header')
    ..onRecord.listen((rec) {
      print(rec);
      if (rec.error != null) print(rec.error);
      if (rec.stackTrace != null) print(rec.stackTrace);
    });
  app.mimeTypeResolver
    ..addExtension('dart', 'text/dart')
    ..addExtension('lock', 'text/plain')
    ..addExtension('md', 'text/plain')
    ..addExtension('packages', 'text/plain')
    ..addExtension('yaml', 'text/plain')
    ..addExtension('yml', 'text/plain');
  app.fallback(vDir.handleRequest);
  app.fallback((req, res) => throw new AngelHttpException.notFound());
  await http.startServer('127.0.0.1', 3000);
  print('Listening at ${http.uri}');
}

class _RangingVirtualDirectory extends VirtualDirectory {
  _RangingVirtualDirectory(Angel app, Directory source)
      : super(app, source.fileSystem,
            source: source, allowDirectoryListing: true);

  @override
  Future<bool> serveFile(
      File file, FileStat stat, RequestContext req, ResponseContext res) async {
    res.headers[HttpHeaders.acceptRangesHeader] = 'bytes';

    if (req.headers.value(HttpHeaders.rangeHeader)?.startsWith('bytes') ==
        true) {
      var header =
          new RangeHeader.parse(req.headers.value(HttpHeaders.rangeHeader));
      header = new RangeHeader(RangeHeader.foldItems(header.items));

      if (header.items.length == 1) {
        var item = header.items[0];
        Stream<Uint8List> stream;
        int len = 0, total = await file.length();

        if (item.start == -1) {
          if (item.end == -1) {
            len = total;
            stream = file.openRead();
          } else {
            len = item.end + 1;
            stream = file.openRead(0, item.end + 1);
          }
        } else {
          if (item.end == -1) {
            len = total - item.start;
            stream = file.openRead(item.start);
          } else {
            len = item.end - item.start + 1;
            stream = file.openRead(item.start, item.end + 1);
          }
        }

        res.contentType = new MediaType.parse(
            app.mimeTypeResolver.lookup(file.path) ??
                'application/octet-stream');
        res.statusCode = HttpStatus.partialContent;
        res.headers[HttpHeaders.contentLengthHeader] = len.toString();
        res.headers[HttpHeaders.contentRangeHeader] =
            'bytes ' + item.toContentRange(total);
        await stream.cast<List<int>>().pipe(res);
        return false;
      } else {
        var totalFileSize = await file.length();
        var transformer = new RangeHeaderTransformer(
            header,
            app.mimeTypeResolver.lookup(file.path) ??
                'application/octet-stream',
            await file.length());
        res.statusCode = HttpStatus.partialContent;
        res.headers[HttpHeaders.contentLengthHeader] =
            transformer.computeContentLength(totalFileSize).toString();
        res.contentType = new MediaType(
            'multipart', 'byteranges', {'boundary': transformer.boundary});
        await file
            .openRead()
            .cast<List<int>>()
            .transform(transformer)
            .pipe(res);
        return false;
      }
    } else {
      return await super.serveFile(file, stat, req, res);
    }
  }
}
