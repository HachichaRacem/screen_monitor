import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_monitor/controllers/main_controller.mobile.dart';

class LoadingAcitivity extends GetView<MainControllerMobile> {
  const LoadingAcitivity({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => controller.showLoadingActivity.value
          ? LinearProgressIndicator(
              borderRadius: BorderRadius.circular(16),
              value: controller.loadingProgressValue.value,
            )
          : const SizedBox(),
    );
  }
}
