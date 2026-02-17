import 'dart:io';

import 'package:flutter/widgets.dart';

Widget? buildLocalFileImageImpl(String path, {required BoxFit fit}) {
  final File localFile = File(path);
  if (!localFile.existsSync()) {
    return null;
  }
  return Image.file(localFile, fit: fit);
}
