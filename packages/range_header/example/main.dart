import 'dart:io';
import 'package:angel3_range_header/angel3_range_header.dart';

var file = File('some_video.mp4');

void handleRequest(HttpRequest request) async {
  // Parse the header
  var header =
      RangeHeader.parse(request.headers.value(HttpHeaders.rangeHeader)!);

  // Optimize/canonicalize it
  var items = RangeHeader.foldItems(header.items);
  header = RangeHeader(items);

  // Get info
  header.items;
  header.rangeUnit;
  header.items.forEach((item) => item.toContentRange(400));

  // Serve the file
  var transformer =
      RangeHeaderTransformer(header, 'video/mp4', await file.length());
  await file
      .openRead()
      .cast<List<int>>()
      .transform(transformer)
      .pipe(request.response);
}
