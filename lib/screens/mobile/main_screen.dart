import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:screen_monitor/controllers/main_controller.mobile.dart';
import 'package:screen_monitor/widgets/mobile/info_tile.dart';
import 'package:screen_monitor/widgets/mobile/loading_activity.dart';

class MainScreenMobile extends GetView<MainControllerMobile> {
  const MainScreenMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        forceMaterialTransparency: true,
        title: Obx(
          () => Tooltip(
            message: controller.isOtherDeviceConnected.value
                ? "Desktop is connected"
                : "Desktop is disconnected",
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              Icons.desktop_mac_rounded,
              color: controller.isOtherDeviceConnected.value
                  ? Colors.green
                  : Colors.grey,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.topCenter,
              child: LoadingAcitivity(),
            ),
            Flexible(
              child: Column(
                children: [
                  Obx(
                    () => controller.latestCapture.value.isEmpty
                        ? const SizedBox(height: 180)
                        : InteractiveViewer(
                            child: Image.memory(
                              controller.latestCapture.value,
                              alignment: Alignment.bottomCenter,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                  ),
                  Flexible(
                    child: Obx(
                      () => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text("General information",
                                    style: Get.textTheme.titleMedium),
                              ),
                            ),
                            InfoTile(
                                title: "Upload Timer",
                                value: controller.uploadTimerValue.value),
                            InfoTile(
                                title: "Urgent action Timer",
                                value: controller.urgentActionTimerValue.value),
                            InfoTile(
                                title: "Urgent action Timer status",
                                value: controller.isUrgentActionActive.value
                                    ? "Active"
                                    : "Inactive"),
                            InfoTile(
                                title: "Urgent action type",
                                value: controller.urgentActionType.value),
                            InfoTile(
                                title: "Network activity",
                                value: controller.networkBandwith.value),
                            InfoTile(
                                title: "CPU Temperature",
                                value: controller.cpuTemperature.value),
                            InfoTile(
                                title: "GPU Temperature",
                                value: controller.gpuTemperature.value),
                            InfoTile(
                                title: "Battery Status",
                                value: controller.batteryPercentage.value),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: controller.onStartUrgentActionClick,
                              child: Obx(
                                () => Text(controller.isUrgentActionActive.value
                                    ? "Stop urgent action (${controller.urgentActionTimeRemaining})"
                                    : "Start urgent action"),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10.0, top: 10),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text("Quick actions",
                                    style: Get.textTheme.titleMedium),
                              ),
                            ),
                            Row(
                              children: [
                                const Spacer(),
                                Flexible(
                                  flex: 2,
                                  child: TextField(
                                    textAlign: TextAlign.center,
                                    controller:
                                        controller.uploadTimerController,
                                    onSubmitted: controller.onUploadTimerSubmit,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: InputDecoration(
                                      labelText: "Upload timer",
                                      labelStyle: Get.textTheme.labelSmall,
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
                                      alignLabelWithHint: true,
                                      border: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(4.0),
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 26),
                                Flexible(
                                  flex: 2,
                                  child: TextField(
                                    onSubmitted:
                                        controller.onUrgentActionTimerSubmit,
                                    controller:
                                        controller.urgentTimerController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      labelText: "Urgent action timer",
                                      labelStyle: Get.textTheme.labelSmall,
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
                                      alignLabelWithHint: true,
                                      border: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(4.0),
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
