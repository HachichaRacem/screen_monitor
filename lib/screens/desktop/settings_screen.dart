import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_monitor/controllers/main_controller_desktop.dart';
import 'package:screen_monitor/widgets/desktop/settings_field_info.dart';
import 'package:screen_monitor/widgets/desktop/settings_input_field.dart';

class SettingsScreenDesktop extends GetView<MainControllerDesktop> {
  const SettingsScreenDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
            flex: 3,
            child: Row(
              children: [
                const Spacer(),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const SettingsFieldInfo(
                          mainText: "Upload Timer",
                          subText:
                              "The amount of seconds to wait between each uploads. Editing this will take action immediately."),
                      const SettingsFieldInfo(
                          mainText: "Urgent Action Timer",
                          subText:
                              "The amount of seconds to wait before taking an urgent action."),
                      Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SettingsFieldInfo(
                                mainText: "Shutdown Urgent Action",
                                subText:
                                    "Enabling this will activate the urgent action timer then shut down the computer."),
                            if (controller.shutdownTimerProgress.value != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: FractionallySizedBox(
                                  widthFactor: 0.8,
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(16),
                                    value:
                                        controller.shutdownTimerProgress.value,
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              SettingsInputField(
                textEditingController: controller.uploadTimerController,
                initialValue: controller.uploadTimerInitialValue,
                saveBtnEnabled: controller.uploadTimerSaveBtnEnabled,
                fieldEnabled: controller.uploadTimerEnabled,
                saveBtnLoading: controller.uploadTimerSaveBtnLoading,
                onSaveBtnPress: controller.onUploadTimerSaveClick,
              ),
              SettingsInputField(
                textEditingController: controller.urgentActionTimerController,
                initialValue: controller.urgentActionTimerInitialValue,
                saveBtnEnabled: controller.urgenttimerSaveBtnEnabled,
                fieldEnabled: controller.urgentActionTimerEnabled,
                saveBtnLoading: controller.urgenttimerSaveBtnLoading,
                onSaveBtnPress: controller.onUrgentTimerSaveClick,
              ),
              Obx(
                () => Switch(
                  onChanged: controller.onShutdownSwitchClick,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  splashRadius: 16,
                  trackOutlineColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  value: controller.shutdownEnabled.value,
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}
