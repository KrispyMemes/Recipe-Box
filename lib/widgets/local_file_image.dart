import 'package:flutter/widgets.dart';

import 'local_file_image_stub.dart'
    if (dart.library.io) 'local_file_image_io.dart'
    if (dart.library.html) 'local_file_image_web.dart';

Widget? buildLocalFileImage(String path, {required BoxFit fit}) {
  return buildLocalFileImageImpl(path, fit: fit);
}
