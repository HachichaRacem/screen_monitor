import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_monitor/controllers/main_controller_desktop.dart';
import 'package:screen_monitor/screens/desktop/home_screen.dart';
import 'package:screen_monitor/screens/desktop/settings_screen.dart';
import 'package:screen_monitor/widgets/desktop/bottom_nav_bar.dart';

class MainScreenDesktop extends GetView<MainControllerDesktop> {
  const MainScreenDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        bottomNavigationBar: const AppBottomNavBar(),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Get.theme.colorScheme.surfaceContainer,
          title: Obx(() => IconButton(
                onPressed: controller.onPlayButtonPress,
                tooltip: controller.isProcessOn.value
                    ? "Pause the process"
                    : "Start capturing and uploading",
                padding: EdgeInsets.zero,
                icon: Icon(
                  controller.isProcessOn.value
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              )),
          leading: Obx(
            () => Tooltip(
              message: controller.isOtherDeviceConnected.value
                  ? "Mobile is Connected"
                  : "Mobile is Disconnected",
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.smartphone_rounded,
                color: controller.isOtherDeviceConnected.value
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
          ),
        ),
        body: PageView(
          controller: controller.pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [HomeScreenDesktop(), SettingsScreenDesktop()],
        ),
      ),
    );
  }
}
