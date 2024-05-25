import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsFieldInfo extends StatelessWidget {
  final String mainText;
  final String subText;
  const SettingsFieldInfo(
      {super.key, required this.mainText, required this.subText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(mainText, style: GoogleFonts.roboto(fontSize: 14)),
        Text(
          subText,
          style: GoogleFonts.roboto(
            color: Get.theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
