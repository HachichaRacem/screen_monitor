import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class Logger {
  static Future<void> log(message, {isError = false}) async {
    debugPrint(message);
    final Directory logDirectory = Platform.isAndroid
        ? (await getExternalStorageDirectories())![0]
        : Directory.current;

    await File('${logDirectory.path}/log.txt')
        .writeAsString("$message\n", mode: FileMode.append, flush: true);
  }
}
