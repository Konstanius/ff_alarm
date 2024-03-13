import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';

Map<String, String>? authData;

class Request {
  Map<String, dynamic> data;
  late DateTime time;
  String type;
  RequestStatus status = RequestStatus.unsent;
  Map<String, dynamic>? ackData;
  AckError? error;

  Request(this.type, this.data);

  static Future<bool> isConnected() async {
    try {
      await Request('ping', {}).emit(true, guest: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Request> emit(
    bool errors, {
    int timeout = 6000,
    Function(double)? uploadProgress,
    Function(double)? downloadProgress,
    CancelToken? cancelToken,
    bool guest = false,
  }) async {
    time = DateTime.now();

    if (!Globals.loggedIn) {
      authData = null;
    } else if (authData == null && !guest) {
      authData = await getAuthData();
    } else if (authData != null && guest) {
      authData = null;
    }

    Map<String, dynamic> headers = {
      't': time.millisecondsSinceEpoch.toString(),
      'to': timeout.toString(),
    };
    if (authData != null && !guest) {
      authData!.forEach((key, value) {
        headers[key] = value;
      });
    }

    BaseOptions options = BaseOptions(
      connectTimeout: Duration(milliseconds: timeout),
      receiveTimeout: Duration(milliseconds: timeout),
      sendTimeout: Duration(milliseconds: timeout),
      headers: headers,
      method: 'POST',
      baseUrl: 'http${Globals.sslAllowance ? 's' : ''}://${Globals.connectionAddress}/${Globals.devPrefix}api/',
      receiveDataWhenStatusError: true,
      validateStatus: (_) {
        return true;
      },
    );

    Dio dio = Dio(options);
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      HttpClient client = HttpClient();
      client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      return client;
    };

    // Convert double (percent 0 to 100) function to int, int function
    Function(int d, int m)? uploadProgressInt = uploadProgress != null ? (int d, int m) => uploadProgress(d / m) : null;
    Function(int d, int m)? downloadProgressInt = downloadProgress != null ? (int d, int m) => downloadProgress(d / m) : null;

    status = RequestStatus.sent;

    cancelToken ??= CancelToken();

    Response<dynamic> response;
    try {
      response = await dio.post(
        'http${Globals.sslAllowance ? 's' : ''}://${Globals.connectionAddress}/${Globals.devPrefix}api/$type',
        data: data,
        onSendProgress: uploadProgressInt,
        onReceiveProgress: downloadProgressInt,
        options: Options(
          validateStatus: (status) {
            return true;
          },
        ),
        cancelToken: cancelToken,
      );
    } catch (e, s) {
      if (!e.toString().contains('timeout') && !e.toString().contains('The connection errored')) {
        Logger.yellow(e);
        Logger.yellow(s);
      }

      error = AckError.timeout;
      status = RequestStatus.timeout;

      // if less than timeout * 0.8 has passed, set error to offline
      if (DateTime.now().millisecondsSinceEpoch - time.millisecondsSinceEpoch < timeout * 0.8) {
        error = AckError.offline;
      }

      try {
        cancelToken.cancel();
      } catch (_) {}
      if (errors) {
        throw error!;
      }
      return this;
    }

    int responseCode = response.statusCode!;
    switch (responseCode) {
      case HttpStatus.ok:
        try {
          status = RequestStatus.acknowledged;

          String responseBody = response.data.toString();
          ackData = jsonDecode(responseBody);
        } catch (e) {
          error = AckError('client', 'Die Antwort des Servers war fehlerhaft');
          status = RequestStatus.failed;
        }
        break;
      case HttpStatus.requestTimeout:
      case HttpStatus.badGateway:
        error = AckError.timeout;
        status = RequestStatus.timeout;
        break;
      case HttpStatus.tooManyRequests:
        error = AckError.tooManyRequests;
        status = RequestStatus.timeout;
        break;
      default:
        String responseBody = response.data.toString();
        Map<String, dynamic> responseJson = jsonDecode(responseBody);
        error = AckError.from(responseJson['error']);
        break;
    }

    if (errors && error != null) {
      throw error!;
    }

    return this;
  }

  static Future<Map<String, String>?> getAuthData() async {
    // TODO

    Map<String, String> headers = {
      "authorization": "testtoken",
    };
    return headers;
  }
}

enum RequestStatus {
  unsent,
  sent,
  acknowledged,
  failed,
  timeout,
}

class AckError {
  String errorCode;
  String errorMessage;

  AckError(this.errorCode, this.errorMessage);

  static AckError get timeout => AckError('timeout', 'Die Anfrage an den Server hat die Zeitüberschreitung erreicht');
  static AckError get offline => AckError('offline', 'Du bist aktuell offline');
  static AckError get tooManyRequests => AckError('tooManyRequests', 'Zu viele Anfragen an den Server. Bitte warte einen Moment und versuche es erneut');
  static AckError get server => AckError('server', 'Ein Serverfehler ist aufgetreten');

  static AckError from(Map<String, dynamic> error) {
    return AckError(error['code'] as String, error['message'] as String);
  }
}
