import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:web_socket_client/web_socket_client.dart';

class MainControllerMobile extends GetxController {
  final int clientID = 1;
  final String apiUrl = "wss://monitor-backend-xutw.onrender.com";
  late final webSocket = WebSocket(Uri.parse(apiUrl));

  final RxBool isOtherDeviceConnected = false.obs;
  final RxBool isConnectedToServer = false.obs;
  final RxBool showLoadingActivity = true.obs;
  final Rx<double?> loadingProgressValue = Rx<double?>(null);

  final Rx<Uint8List> latestCapture = Rx(Uint8List(0));

  final TextStyle titleStyle =
      GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14);
  final TextStyle valueStyle = GoogleFonts.poppins(fontSize: 11);

  final RxString uploadTimerValue = "...".obs;
  final RxString urgentActionTimerValue = "...".obs;
  final RxString urgentActionType = "...".obs;
  final RxString networkBandwith = "- KB/s".obs;
  final RxString cpuTemperature = "- C".obs;
  final RxString gpuTemperature = "- C".obs;
  final RxString batteryPercentage = "- %".obs;
  final RxBool isUrgentActionActive = false.obs;
  final RxInt urgentActionTimeRemaining = 0.obs;

  final TextEditingController uploadTimerController = TextEditingController();
  final TextEditingController urgentTimerController = TextEditingController();
  @override
  void onReady() async {
    super.onReady();
    try {
      await _connectToServer();
    } catch (e, stack) {
      Get.log("[ERROR - ${DateTime.now()}] Failed to connect (ERROR) - $e",
          isError: true);
      Get.log("[ERROR - ${DateTime.now()}] Failed to connect (STACK) - $stack",
          isError: true);
    }
  }

  Future<void> _connectToServer() async {
    webSocket.connection.listen((status) {
      switch (status) {
        case Connecting():
          isConnectedToServer.value = false;
          showLoadingActivity.value = true;
          break;
        case Connected():
          Get.log("[INFO - ${DateTime.now()}] Connceted");
          _sendHandshake();
          break;
        case Reconnecting():
          isConnectedToServer.value = false;
          showLoadingActivity.value = true;
          break;
        case Reconnected():
          Get.log("[INFO - ${DateTime.now()}] Reconnected");
          _sendHandshake();
          break;
        case Disconnected():
          isConnectedToServer.value = false;
          Get.log("[INFO - ${DateTime.now()}] Disconnected");
          break;
      }
    });
    webSocket.messages.listen(
      (payload) {
        final decodedPayload = json.decode(payload);
        switch (decodedPayload['type']) {
          case "CONNECTED_CLIENTS":
            Get.log(
                "[INFO - ${DateTime.now()}] Connected clients: ${decodedPayload['clientIDs']}");
            _handleConnectedClients(decodedPayload);
            break;
          case "SETTINGS":
            _initSettings(decodedPayload['settings']);
            break;
          case "UPDATE":
            _handleUpdate(decodedPayload);
            break;
          default:
            Get.log(
                "[INFO - ${DateTime.now()}] Unknown message: $decodedPayload");
            break;
        }
      },
      onError: (error) => Get.log(
          "[ERROR - ${DateTime.now()}] Error listening to message from server: $error"),
    );
  }

  _handleConnectedClients(Map payload) {
    if (payload['clientIDs'] != null) {
      isOtherDeviceConnected.value = (payload['clientIDs'] as List).isNotEmpty;
    }
  }

  _initSettings(Map payload) {
    Get.log("[INFO - ${DateTime.now()}] Received settings: $payload");
    if (payload['last_capture_url'] != null) {
      showLoadingActivity.value = true;
      _downloadCapture(payload['last_capture_url']);
    }
    uploadTimerValue.value = "${payload['timer_interval']} seconds";
    urgentActionTimeRemaining.value = payload['urgent_action_timer'];
    urgentActionTimerValue.value = "${payload['urgent_action_timer']} seconds";
    urgentActionType.value =
        payload['urgent_action_type'] == 0 ? "Shutdown" : "Unknown";
    isUrgentActionActive.value = payload['is_urgent_timer_active'] == 1;
  }

  _downloadCapture(String url) async {
    if (!showLoadingActivity.value) {
      showLoadingActivity.value = true;
    }
    final response =
        await http.Client().send(http.Request('GET', Uri.parse(url)));
    final totalBytes = response.contentLength ?? 0;
    final List<int> downloadedBytes = [];
    response.stream.listen((value) {
      if (totalBytes != 0) {
        loadingProgressValue.value = downloadedBytes.length / totalBytes;
      }
      downloadedBytes.addAll(value);
    }, onDone: () {
      latestCapture.value = Uint8List.fromList(downloadedBytes);
      showLoadingActivity.value = false;
    }, onError: (error) {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to download capture - $error");
      showLoadingActivity.value = false;
    });
  }

  _sendHandshake() {
    try {
      webSocket.send(
          json.encode({"type": "CLIENT_HANDSHAKE", "clientID": clientID}));
      isConnectedToServer.value = true;
      showLoadingActivity.value = false;
    } catch (e, stack) {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to send handshake (ERROR) - $e",
          isError: true);
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to send handshake (STACK) - $stack",
          isError: true);
    }
  }

  onStartUrgentActionClick() async {
    isUrgentActionActive.toggle();
    webSocket.send(json.encode({
      "type": "IS_URGENT_ACTION_ACTIVE",
      "isUrgentActionActive": isUrgentActionActive.value,
    }));
  }

  _handleUpdate(Map payload) {
    switch (payload['updated']) {
      case "UPLOAD_TIMER":
        uploadTimerValue.value = "${payload['value']} seconds";
        uploadTimerController.text = "";
        break;
      case "URGENT_ACTION_TIMER":
        urgentActionTimeRemaining.value = int.parse(payload['value']);
        urgentActionTimerValue.value = "${payload['value']} seconds";
        urgentTimerController.text = "";
        break;
      case "URGENT_ACTION_TYPE":
        urgentActionType.value = payload['value'] == 0 ? "Shutdown" : "Unknown";
        break;
      case "IS_URGENT_ACTION_ACTIVE":
        isUrgentActionActive.value = payload['value'];
        if (!isUrgentActionActive.value) {
          urgentActionTimeRemaining.value =
              int.parse(urgentActionTimerValue.split("seconds")[0].trim());
        }
        break;
      case "LAST_CAPTURE_URL":
        _downloadCapture(payload['value']);
        break;
      case "URGENT_TIMER_TICK":
        urgentActionTimeRemaining.value -= 1;
        break;
      case "NETWORK_BANDWITH":
        networkBandwith.value = payload['value'];
        break;
      case "CPU_TEMPERATURE":
        cpuTemperature.value = payload['value'];
        break;
      case "GPU_TEMPERATURE":
        gpuTemperature.value = payload['value'];
        break;
      case "BATTERY_STATUS":
        batteryPercentage.value = payload['value'];
        break;
      default:
        Get.log("[INFO - ${DateTime.now()}] Unknown update: $payload");
        break;
    }
  }

  onUploadTimerSubmit(String value) {
    if (value.isNotEmpty) {
      webSocket.send(
        json.encode({
          "type": "UPDATE_UPLOAD_TIMER",
          "uploadTime": value,
        }),
      );
    }
  }

  onUrgentActionTimerSubmit(String value) {
    if (value.isNotEmpty) {
      webSocket.send(json.encode({
        "type": "UPDATE_URGENT_TIMER",
        "urgentTime": value,
      }));
    }
  }
}
