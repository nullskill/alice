import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alice/core/alice_utils.dart';
import 'package:alice/helper/alice_alert_helper.dart';
import 'package:alice/helper/alice_conversion_helper.dart';
import 'package:alice/model/alice_http_call.dart';
import 'package:alice/utils/alice_parser.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AliceSaveHelper {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Top level method used to save calls to file
  static void saveCalls(
    BuildContext context,
    List<AliceHttpCall> calls,
    Brightness brightness,
  ) {
    _checkPermissions(context, calls, brightness);
  }

  static void _checkPermissions(
    BuildContext context,
    List<AliceHttpCall> calls,
    Brightness brightness,
  ) async {
    final status = await Permission.storage.status;
    if (status.isGranted) {
      _saveToFile(
        context,
        calls,
        brightness,
      );
    } else {
      final status = await Permission.storage.request();

      if (status.isGranted) {
        _saveToFile(context, calls, brightness);
      } else {
        AliceAlertHelper.showAlert(
          context,
          'Permission error',
          "Permission not granted. Couldn't save logs.",
          brightness: brightness,
        );
      }
    }
  }

  static Future<String> _saveToFile(
    BuildContext context,
    List<AliceHttpCall> calls,
    Brightness brightness,
  ) async {
    try {
      if (calls.isEmpty) {
        AliceAlertHelper.showAlert(
          context,
          'Error',
          'There are no logs to save',
          brightness: brightness,
        );
        return "";
      }
      final bool isAndroid = Platform.isAndroid;

      Directory? externalDir;
      if (isAndroid) {
        externalDir = await getExternalStorageDirectory();
      } else {
        externalDir = await getApplicationDocumentsDirectory();
      }
      if (externalDir != null) {
        final String fileName = 'alice_log_${DateTime.now().millisecondsSinceEpoch}.txt';
        final File file = File('${externalDir.path}/$fileName');
        file.createSync();
        final IOSink sink = file.openWrite(mode: FileMode.append);
        sink.write(await _buildAliceLog());
        calls.forEach((AliceHttpCall call) {
          sink.write(_buildCallLog(call));
        });
        await sink.flush();
        await sink.close();
        AliceAlertHelper.showAlert(
          context,
          'Success',
          'Successfully saved logs in ${file.path}',
          secondButtonTitle: isAndroid ? 'View file' : null,
          secondButtonAction: () => isAndroid ? OpenFilex.open(file.path) : null,
          brightness: brightness,
        );
        return file.path;
      } else {
        AliceAlertHelper.showAlert(
          context,
          'Error',
          'Failed to save http calls to file',
        );
      }
    } catch (exception) {
      AliceAlertHelper.showAlert(
        context,
        'Error',
        'Failed to save http calls to file',
        brightness: brightness,
      );
      AliceUtils.log(exception.toString());
    }

    return "";
  }

  static Future<String> _buildAliceLog() async {
    final StringBuffer stringBuffer = StringBuffer();
    final packageInfo = await PackageInfo.fromPlatform();
    stringBuffer.writeln('Alice - HTTP Inspector');
    stringBuffer.writeln('App name:  ${packageInfo.appName}');
    stringBuffer.writeln('Package: ${packageInfo.packageName}');
    stringBuffer.writeln('Version: ${packageInfo.version}');
    stringBuffer.writeln('Build number: ${packageInfo.buildNumber}');
    stringBuffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    stringBuffer.writeln();
    return stringBuffer.toString();
  }

  static String _buildCallLog(AliceHttpCall call) {
    final requestContentType = call.request!.contentType ?? '';
    if (requestContentType.isNotEmpty) {
      if (requestContentType.contains('multipart/form-data')) {
        return _buildFormDataCallLog(call, requestContentType);
      }
    }

    return _buildTextCallLog(call, requestContentType);
  }

  static String _buildTextCallLog(AliceHttpCall call, String requestContentType) {
    final StringBuffer stringBuffer = StringBuffer();
    stringBuffer.writeln('===========================================');
    stringBuffer.writeln('Id: ${call.id}');
    stringBuffer.writeln('============================================');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('General data');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Server: ${call.server} ');
    stringBuffer.writeln('Method: ${call.method} ');
    stringBuffer.writeln('Endpoint: ${call.endpoint} ');
    stringBuffer.writeln('Client: ${call.client} ');
    stringBuffer.writeln('Duration ${AliceConversionHelper.formatTime(call.duration)}');
    stringBuffer.writeln('Secured connection: ${call.secure}');
    stringBuffer.writeln('Completed: ${!call.loading} ');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Request');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Request time: ${call.request!.time}');
    stringBuffer.writeln('Request content type: ${call.request!.contentType}');
    stringBuffer.writeln('Request cookies: ${_encoder.convert(call.request!.cookies)}');
    stringBuffer.writeln('Request headers: ${_encoder.convert(call.request!.headers)}');
    if (call.request!.queryParameters.isNotEmpty) {
      stringBuffer.writeln(
        'Request query params: ${_encoder.convert(call.request!.queryParameters)}',
      );
    }
    stringBuffer.writeln(
      'Request size: ${AliceConversionHelper.formatBytes(call.request!.size)}',
    );
    stringBuffer.writeln(
      'Request body: ${AliceParser.formatBody(call.request!.body, requestContentType)}',
    );
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Response');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Response time: ${call.response!.time}');
    stringBuffer.writeln('Response status: ${call.response!.status}');
    stringBuffer.writeln(
      'Response size: ${AliceConversionHelper.formatBytes(call.response!.size)}',
    );
    stringBuffer.writeln(
      'Response headers: ${_encoder.convert(call.response!.headers)}',
    );
    stringBuffer.writeln(
      'Response body: ${AliceParser.formatBody(call.response!.body, AliceParser.getContentType(call.response!.headers))}',
    );
    if (call.error != null) {
      stringBuffer.writeln('--------------------------------------------');
      stringBuffer.writeln('Error');
      stringBuffer.writeln('--------------------------------------------');
      stringBuffer.writeln('Error: ${call.error!.error}');
      if (call.error!.stackTrace != null) {
        stringBuffer.writeln('Error stacktrace: ${call.error!.stackTrace}');
      }
    }
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Curl');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.write(call.getCurlCommand());
    stringBuffer.writeln();
    stringBuffer.writeln('==============================================');
    stringBuffer.writeln();

    return stringBuffer.toString();
  }

  static String _buildFormDataCallLog(AliceHttpCall call, String requestContentType) {
    final StringBuffer stringBuffer = StringBuffer();
    stringBuffer.writeln('===========================================');
    stringBuffer.writeln('Id: ${call.id}');
    stringBuffer.writeln('============================================');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('General data');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Server: ${call.server} ');
    stringBuffer.writeln('Method: ${call.method} ');
    stringBuffer.writeln('Endpoint: ${call.endpoint} ');
    stringBuffer.writeln('Client: ${call.client} ');
    stringBuffer.writeln('Duration ${AliceConversionHelper.formatTime(call.duration)}');
    stringBuffer.writeln('Secured connection: ${call.secure}');
    stringBuffer.writeln('Completed: ${!call.loading} ');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Request');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Request time: ${call.request!.time}');
    stringBuffer.writeln('Request content type: ${call.request!.contentType}');
    stringBuffer.writeln('Request cookies: ${_encoder.convert(call.request!.cookies)}');
    stringBuffer.writeln('Request headers: ${_encoder.convert(call.request!.headers)}');
    if (call.request!.queryParameters.isNotEmpty) {
      stringBuffer.writeln(
        'Request query params: ${_encoder.convert(call.request!.queryParameters)}',
      );
    }
    stringBuffer.writeln(
      'Request size: ${AliceConversionHelper.formatBytes(call.request!.size)}',
    );
    stringBuffer.writeln(
      'Request fields: ${AliceParser.formatFields(call.request!.formDataFields)}',
    );
    stringBuffer.writeln(
      'Request files: ${AliceParser.formatFields(call.request!.formDataFiles)}',
    );
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Response');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Response time: ${call.response!.time}');
    stringBuffer.writeln('Response status: ${call.response!.status}');
    stringBuffer.writeln(
      'Response size: ${AliceConversionHelper.formatBytes(call.response!.size)}',
    );
    stringBuffer.writeln(
      'Response headers: ${_encoder.convert(call.response!.headers)}',
    );
    stringBuffer.writeln(
      'Response body: ${AliceParser.formatBody(call.response!.body, AliceParser.getContentType(call.response!.headers))}',
    );
    if (call.error != null) {
      stringBuffer.writeln('--------------------------------------------');
      stringBuffer.writeln('Error');
      stringBuffer.writeln('--------------------------------------------');
      stringBuffer.writeln('Error: ${call.error!.error}');
      if (call.error!.stackTrace != null) {
        stringBuffer.writeln('Error stacktrace: ${call.error!.stackTrace}');
      }
    }
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.writeln('Curl');
    stringBuffer.writeln('--------------------------------------------');
    stringBuffer.write(call.getCurlCommand());
    stringBuffer.writeln();
    stringBuffer.writeln('==============================================');
    stringBuffer.writeln();

    return stringBuffer.toString();
  }

  static Future<String> buildCallLog(AliceHttpCall call) async {
    try {
      return await _buildAliceLog() + _buildCallLog(call);
    } catch (exception) {
      return 'Failed to generate call log';
    }
  }
}
