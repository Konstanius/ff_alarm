import 'package:ff_alarm/globals.dart';
import 'package:flutter/material.dart';

Future<dynamic> generalDialog({
  required Color color,
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  return showDialog(
    barrierColor: Theme.of(Globals.context!).colorScheme.background.withOpacity(0.5),
    useSafeArea: true,
    barrierDismissible: true,
    context: Globals.context!,
    builder: (BuildContext context) {
      return AlertDialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: color,
            width: 2,
          ),
        ),
        backgroundColor: Theme.of(Globals.context!).colorScheme.background.withBlue(color.blue ~/ 7).withGreen(color.green ~/ 7).withRed(color.red ~/ 7),
        title: Text(title, style: Theme.of(Globals.context!).textTheme.titleLarge!.copyWith(color: color)),
        content: SingleChildScrollView(child: content),
        actions: actions,
      );
    },
  );
}
