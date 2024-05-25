import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InfoTile extends StatelessWidget {
  final String title;
  final String value;
  const InfoTile({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Get.width * 0.75),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Get.textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: Get.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
