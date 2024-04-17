import 'dart:math';

import 'package:another_flushbar/flushbar.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:flutter/material.dart';

List<MapEntry<int, Flushbar>> _toastList = [];

void _generalToast({required String message, required Color color}) {
  int id = Random().nextInt(1000000000);

  Flushbar bar = Flushbar(
    message: message,
    messageSize: Theme.of(Globals.context!).textTheme.bodyMedium!.fontSize,
    messageColor: Colors.white,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    positionOffset: 60,
    borderColor: color,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    backgroundColor: Theme.of(Globals.context!).colorScheme.background.withBlue(color.blue ~/ 3).withGreen(color.green ~/ 3).withRed(color.red ~/ 3),
    padding: const EdgeInsets.all(20),
    onTap: (bar) => bar.dismiss(),
    onStatusChanged: (status) {
      if (status == FlushbarStatus.DISMISSED) {
        _toastList.removeWhere((element) => element.key == id);
      }
    },
    animationDuration: const Duration(milliseconds: 500),
    duration: const Duration(seconds: 5),
    mainButton: IconButton(
      icon: Icon(
        Icons.close_outlined,
        color: color,
      ),
      onPressed: () {
        if (_toastList.any((element) => element.key == id)) {
          _toastList.firstWhere((element) => element.key == id).value.dismiss();
        }
      },
    ),
  );

  _toastList.add(MapEntry(id, bar));
  bar.show(Globals.context!).catchError((e, s) {
    _toastList.removeWhere((element) => element.key == id);
  });

  // dismiss all other toasts
  for (var element in _toastList) {
    if (element.key != id) {
      element.value.dismiss();
    }
  }
}

void errorToast(String text) {
  _generalToast(
    message: text,
    color: Colors.red[700]!,
  );
}

void successToast(String text) {
  _generalToast(
    message: text,
    color: Colors.green[700]!,
  );
}

void infoToast(String text) {
  _generalToast(
    message: text,
    color: Colors.blue[700]!,
  );
}

void exceptionToast(e, s) {
  if (e is AckError) {
    Logger.warn(e.errorMessage);
    errorToast(e.errorMessage);
  } else {
    Logger.error("$e\n$s");
    errorToast('Ein unbekannter Fehler ist aufgetreten');
  }
}
