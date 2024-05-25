import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_monitor/controllers/main_controller.mobile.dart';
import 'package:screen_monitor/controllers/main_controller_desktop.dart';
import 'package:screen_monitor/screens/desktop/main_screen.dart';
import 'package:screen_monitor/screens/mobile/main_screen.dart';
import 'package:screen_monitor/utils/logger.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      logWriterCallback: Logger.log,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A1A1A), brightness: Brightness.dark),
      ),
      initialBinding: Platform.isAndroid
          ? BindingsBuilder.put(() => MainControllerMobile())
          : BindingsBuilder.put(() => MainControllerDesktop()),
      home: Platform.isWindows
          ? const MainScreenDesktop()
          : const MainScreenMobile(),
    );
  }
}
