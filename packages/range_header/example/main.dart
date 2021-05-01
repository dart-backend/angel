import 'dart:io';
import 'package:range_header/range_header.dart';

var file = new File('some_video.mp4');

handleRequest(HttpRequest request) async {
  // Parse the header
  var header =
      new RangeHeader.parse(request.headers.value(HttpHeaders.rangeHeader));

  // Optimize/canonicalize it
  var items = RangeHeader.foldItems(header.items);
  header = new RangeHeader(items);

  // Get info
  header.items;
  header.rangeUnit;
  header.items.forEach((item) => item.toContentRange(400));

  // Serve the file
  var transformer =
      new RangeHeaderTransformer(header, 'video/mp4', await file.length());
  await file
      .openRead()
      .cast<List<int>>()
      .transform(transformer)
      .pipe(request.response);
}
