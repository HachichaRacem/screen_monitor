import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_monitor/controllers/main_controller_desktop.dart';

class HomeScreenDesktop extends GetView<MainControllerDesktop> {
  const HomeScreenDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => controller.isConnected.value
          ? controller.latestCapture.value.isEmpty
              ? const Center(child: Text("Fetching latest capture"))
              : InteractiveViewer(
                  child: Image.memory(
                  controller.latestCapture.value,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ))
          : const Center(child: Text("Connecting to server")),
    );
  }
}
