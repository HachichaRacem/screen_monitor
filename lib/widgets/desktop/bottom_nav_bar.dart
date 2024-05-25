import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_monitor/controllers/main_controller_desktop.dart';

class AppBottomNavBar extends GetView<MainControllerDesktop> {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.showLoadingActivity.value)
            LinearProgressIndicator(
              value: controller.progressIndicatorValue.value,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
          NavigationBar(
            onDestinationSelected: controller.onDestinationSelected,
            selectedIndex: controller.selectedNavBarIndex.value,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                selectedIcon: Icon(Icons.settings),
                icon: Icon(Icons.settings_outlined),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
