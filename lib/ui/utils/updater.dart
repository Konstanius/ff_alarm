import 'dart:async';

import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class UpdateInfo {
  UpdateType type;
  Set<int> ids = {};

  UpdateInfo(this.type, [this.ids = const {}]) {
    if (kDebugMode) {
      String stack = Utils.getAppStack(2);
      Logger.updateStream("$type: $ids from $stack");
    }

    Globals.updateStream.add(this);
  }
}

enum UpdateType {
  station,
  unit,
  alarm,
  person,
  settings,

  /// UI update ids:
  /// 0 = app resumed
  ui,
  other;
}

mixin Updates<T extends StatefulWidget> on State<T> {
Set<UpdateType> _listensTo = {};

  void onUpdate(UpdateInfo info);

  void setupListener(Set<UpdateType> types) {
    _listensTo = types;

    _updateStream?.cancel();
    _updateStream = Globals.updateStream.stream.listen((UpdateInfo info) {
      if (_listensTo.contains(info.type)) {
        onUpdate(info);
      }
    });
  }

  StreamSubscription<UpdateInfo>? _updateStream;

  @override
  void dispose() {
    _updateStream?.cancel();
    super.dispose();
  }
}

mixin DateTimeChangeListener<T extends StatefulWidget> on State<T> {
  void onDateTimeChangeExecution();

  Timer? _dateTimeUpdateTimer;

  void setupDateTimeChangeListener(Duration duration, DateTime firstExecution) {
    if (_dateTimeUpdateTimer != null) _dateTimeUpdateTimer?.cancel();

    while (firstExecution.isBefore(DateTime.now())) {
      firstExecution = firstExecution.add(duration);
    }

    Duration difference = firstExecution.difference(DateTime.now());

    Future.delayed(difference).then((value) {
      if (mounted) onDateTimeChangeExecution();
      _dateTimeUpdateTimer = Timer.periodic(duration, (timer) {
        if (mounted) {
          onDateTimeChangeExecution();
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _dateTimeUpdateTimer?.cancel();
  }
}
