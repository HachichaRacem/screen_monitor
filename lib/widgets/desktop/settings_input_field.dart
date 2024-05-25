import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsInputField extends StatelessWidget {
  final TextEditingController textEditingController;
  final RxString initialValue;
  final RxBool saveBtnEnabled;
  final RxBool fieldEnabled;
  final RxBool saveBtnLoading;
  final Function() onSaveBtnPress;
  late final FocusNode focusNode = FocusNode()
    ..addListener(() {
      if (!focusNode.hasFocus && textEditingController.text.isEmpty) {
        textEditingController.text = initialValue.value;
        saveBtnEnabled.value = false;
      }
    });
  SettingsInputField(
      {super.key,
      required this.textEditingController,
      required this.initialValue,
      required this.saveBtnEnabled,
      required this.fieldEnabled,
      required this.saveBtnLoading,
      required this.onSaveBtnPress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
            width: 80,
            child: Obx(
              () => TextField(
                focusNode: focusNode,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: textEditingController,
                textAlign: TextAlign.center,
                enabled: fieldEnabled.value,
                onChanged: (value) => saveBtnEnabled.value =
                    value.isNotEmpty && value != initialValue.value,
                style: GoogleFonts.roboto(),
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                ),
              ),
            )),
        const SizedBox(width: 8),
        Obx(
          () => AnimatedOpacity(
            opacity: saveBtnEnabled.value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: saveBtnLoading.value
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: const Padding(
                padding: EdgeInsets.all(3.0),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 3.0, strokeCap: StrokeCap.round),
                ),
              ),
              secondChild: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: onSaveBtnPress,
                icon: const Icon(Icons.check_rounded),
              ),
            ),
          ),
        )
      ],
    );
  }
}
