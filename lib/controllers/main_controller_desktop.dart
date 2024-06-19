import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_compression/image_compression.dart';
import 'package:web_socket_client/web_socket_client.dart';
import 'package:win32/win32.dart';

class MainControllerDesktop extends GetxController {
  // Global configuration
  final int clientID = 0;
  static const String apiUrl = "wss://monitor-backend-xutw.onrender.com";
  late final webSocket = WebSocket(Uri.parse(apiUrl));

  // State management
  final RxBool showLoadingActivity = true.obs;
  final Rx<double?> progressIndicatorValue = Rx(null);
  final RxBool isConnected = false.obs;
  final RxInt selectedNavBarIndex = 0.obs;
  final RxBool isOtherDeviceConnected = false.obs;
  final Rx<Uint8List> latestCapture = Rx(Uint8List(0));
  final RxBool isProcessOn = false.obs;

  // Process related variables
  Timer? timer;
  Completer? _taskCompleter;

  // Settings screen related variables
  int urgentActionType = 0; // 0 = Shutdown

  final Rx<double?> shutdownTimerProgress = Rx<double?>(null);

  final RxBool shutdownEnabled = false.obs;

  final RxBool isUploadTimerFieldEnabled = false.obs;
  final RxBool isUrgentActionTimerFieldEnabled = false.obs;

  final TextEditingController uploadTimerController = TextEditingController();
  final TextEditingController urgentActionTimerController =
      TextEditingController();

  final RxString uploadTimerInitialValue = "".obs;
  final RxString urgentActionTimerInitialValue = "".obs;

  final RxBool isUploadTimerSaveBtnEnabled = false.obs;
  final RxBool isUploadTimerSaveBtnLoading = false.obs;

  final RxBool isUrgentTimerSaveBtnEnabled = false.obs;
  final RxBool isUrgentTimerSaveBtnLoading = false.obs;

  Completer? _updateUploadTimerTask;
  Completer? _updateUrgentTimerTask;
  Completer? _shutdownUrgentActionTask;

  Timer? urgentActionTimer;
  Isolate? _updateInfoIsolate;

  // Other variables
  final PageController pageController = PageController();

  static Future<void> startWebSocket(String url) async {
    final webSocket = WebSocket(Uri.parse(url));
    Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        _sendNetworkBandwith(webSocket);
        _sendGPUTemp(webSocket);
        _sendCPUTemp(webSocket);
        _sendBatteryInfo(webSocket);
      } catch (e, stack) {
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update system info (ERROR) - $e",
            isError: true);
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update system info (STACK) - $stack",
            isError: true);
      }
    });
  }

  static void webSocketIsolateEntryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    startWebSocket(apiUrl);
  }

  @override
  void onReady() async {
    super.onReady();
    try {
      showLoadingActivity.value = true;
      await _connectToServer();
    } catch (e, stack) {
      Get.log("[ERROR - ${DateTime.now()}] Failed to connect (ERROR) - $e",
          isError: true);
      Get.log("[ERROR - ${DateTime.now()}] Failed to connect (STACK) - $stack",
          isError: true);
    } finally {
      showLoadingActivity.value = false;
    }
  }

  void _spawnIsolate() {
    final ReceivePort receivePort = ReceivePort();
    Isolate.spawn(webSocketIsolateEntryPoint, receivePort.sendPort).then(
      (isolate) {
        Get.log(
            "[INFO - ${DateTime.now()}] Isolate to update system info spawned successfully");
        _updateInfoIsolate = isolate;
      },
      onError: (error, stack) => Get.log(
        "[ERROR - ${DateTime.now()}] Isolate did not spawn (ERROR + STACK) - $error\n$stack",
      ),
    );
  }

  void _killIsolate() {
    if (_updateInfoIsolate != null) {
      Get.log("[INFO - ${DateTime.now()}] Killed isolate");
      _updateInfoIsolate!.kill(priority: Isolate.immediate);
    }
  }

  @override
  void onClose() {
    webSocket.close();
    _killIsolate();
    super.onClose();
  }

  // Server communication methods
  Future<void> _connectToServer() async {
    webSocket.connection.listen((status) {
      switch (status) {
        case Connecting():
          showLoadingActivity.value = true;
          break;
        case Connected():
          Get.log("[INFO - ${DateTime.now()}] Connceted");
          _sendHandshake();
          _spawnIsolate();
          break;
        case Reconnecting():
          _killIsolate();
          showLoadingActivity.value = true;
          break;
        case Reconnected():
          Get.log("[INFO - ${DateTime.now()}] Reconnected");
          _sendHandshake();
          _spawnIsolate();
          break;
        case Disconnected():
          Get.log("[INFO - ${DateTime.now()}] Disconnected");
          isConnected.value = false;
          _killIsolate();
          break;
      }
    });
    webSocket.messages.listen(
      (payload) {
        final decodedPayload = json.decode(payload);
        switch (decodedPayload['type']) {
          case "SETTINGS":
            if (decodedPayload['settings'] != null) {
              _initSettingsParams(decodedPayload['settings']);
            } else {
              Get.log(
                  "[ERROR - ${DateTime.now()}] Failed to get settings from server");
            }
            break;
          case "CONNECTED_CLIENTS":
            Get.log(
                "[INFO - ${DateTime.now()}] Connected clients: ${decodedPayload['clientIDs']}");
            _handleConnectedClients(decodedPayload);
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

  _handleUpdate(Map payload) {
    switch (payload['updated']) {
      case "UPLOAD_TIMER":
        if (payload['error'] == null) {
          if (_updateUploadTimerTask != null &&
              !_updateUploadTimerTask!.isCompleted) {
            _updateUploadTimerTask?.complete();
          } else {
            uploadTimerInitialValue.value = "${payload['value']}";
            uploadTimerController.text = "${payload['value']}";
          }
        } else {
          Get.log(
              "[ERROR - ${DateTime.now()}] Failed to update upload timer (response failed from server)");
          if (_updateUploadTimerTask != null &&
              !_updateUploadTimerTask!.isCompleted) {
            _updateUploadTimerTask?.completeError(payload['error']);
          }
        }
        break;
      case "URGENT_ACTION_TIMER":
        if (payload['error'] == null) {
          if (_updateUrgentTimerTask != null &&
              !_updateUrgentTimerTask!.isCompleted) {
            _updateUrgentTimerTask?.complete();
          } else {
            urgentActionTimerInitialValue.value = "${payload['value']}";
            urgentActionTimerController.text = "${payload['value']}";
          }
        } else {
          Get.log(
              "[ERROR - ${DateTime.now()}] Failed to update urgent timer (response failed from server)");
          if (_updateUrgentTimerTask != null &&
              !_updateUrgentTimerTask!.isCompleted) {
            _updateUrgentTimerTask?.completeError(payload['error']);
          }
        }
        break;
      case "IS_URGENT_ACTION_ACTIVE":
        _handleIsUrgentActionActive(payload);
        break;
      case "LAST_CAPTURE_URL":
        if (!payload.containsKey("error")) {
          Get.log("[INFO - ${DateTime.now()}] Received capture successfully");
          _downloadCapture(payload['value']);
        } else {
          Get.log(
              "[ERROR - ${DateTime.now()}] Failed to upload capture (response failed from server) : ${payload['error']}");
          showLoadingActivity.value = false;
          if (_taskCompleter != null && !_taskCompleter!.isCompleted) {
            _taskCompleter!.completeError(payload['error']);
          }
        }
        break;
      default:
        Get.log("[INFO - ${DateTime.now()}] Unknown update: $payload");
        break;
    }
  }

  _handleIsUrgentActionActive(Map payload) {
    if (payload['value'] != null) {
      final bool isUrgentActionActive = payload['value'];
      if (isUrgentActionActive) {
        if (payload['extra']['urgentAction'] != null) {
          if (payload['extra']['urgentAction'] == 0) {
            shutdownEnabled.value = true;
            urgentActionTimer?.cancel();
            Get.log(
                "[INFO - ${DateTime.now()}] Shutdown urgent action timer is about to begin");
            urgentActionTimer =
                Timer.periodic(const Duration(seconds: 1), (timer) async {
              if (!shutdownEnabled.value) {
                shutdownTimerProgress.value = null;
                Get.log(
                    "[INFO - ${DateTime.now()}] Shutdown urgent action cancelled by user");
                timer.cancel();
              } else {
                final int actionTimerValue =
                    int.parse(urgentActionTimerInitialValue.value);
                _sendUrgentActionTimerTick();
                if (timer.tick % actionTimerValue == 0) {
                  shutdownTimerProgress.value = null;
                  Get.log(
                      "[INFO - ${DateTime.now()}] Shutdown urgent action should take place");
                  _updateIsUrgentActionActive(false);
                  _executeShutdown();
                  shutdownEnabled.value = false;
                  timer.cancel();
                } else {
                  shutdownTimerProgress.value =
                      (timer.tick % actionTimerValue) / actionTimerValue;
                }
              }
            });
            _shutdownUrgentActionTask?.complete();
          }
        } else if (payload['error'] != null) {
          Get.log(
              "[ERROR - ${DateTime.now()}] Failed to update IS_URGENT_TIMER_ACTIVE (response failed from server)");
          if (_shutdownUrgentActionTask != null &&
              !_shutdownUrgentActionTask!.isCompleted) {
            _shutdownUrgentActionTask?.completeError(payload["error"]);
          }
        }
      } else {
        urgentActionTimer?.cancel();
        shutdownTimerProgress.value = null;
        Get.log(
            "[INFO - ${DateTime.now()}] Shutdown urgent action cancelled by user");
        shutdownEnabled.value = false;
      }
    }
  }

  _initSettingsParams(Map payload) {
    if (payload['last_capture_url'] != "") {
      showLoadingActivity.value = true;
      _downloadCapture(payload['last_capture_url']);
    }
    uploadTimerController.text = "${payload['timer_interval'] ?? 60}";
    uploadTimerInitialValue.value = "${payload['timer_interval'] ?? 60}";
    isUploadTimerFieldEnabled.value = true;
    urgentActionTimerController.text =
        "${payload['urgent_action_timer'] ?? 60}";
    urgentActionTimerInitialValue.value =
        "${payload['urgent_action_timer'] ?? 60}";
    isUrgentActionTimerFieldEnabled.value = true;
    urgentActionType = payload['urgent_action_type'] ?? 0;
  }

  _sendHandshake() {
    try {
      webSocket.send(
          json.encode({"type": "CLIENT_HANDSHAKE", "clientID": clientID}));
      showLoadingActivity.value = false;
      isConnected.value = true;
    } catch (e, stack) {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to send handshake (ERROR) - $e",
          isError: true);
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to send handshake (STACK) - $stack",
          isError: true);
    }
  }

  // Navigation methods
  void onDestinationSelected(int index) {
    if (index != selectedNavBarIndex.value) {
      selectedNavBarIndex.value = index;
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeIn,
      );
    }
  }

  // Process methods
  static void _sendNetworkBandwith(WebSocket webSocket) async {
    try {
      var hr = CoInitializeEx(nullptr, COINIT.COINIT_APARTMENTTHREADED);
      if (FAILED(hr)) throw WindowsException(hr);

      final pLoc = IWbemLocator(calloc<COMObject>());

      final clsid = calloc<GUID>()..ref.setGUID(CLSID_WbemLocator);
      final iid = calloc<GUID>()..ref.setGUID(IID_IWbemLocator);

      hr = CoCreateInstance(
          clsid, nullptr, CLSCTX.CLSCTX_INPROC_SERVER, iid, pLoc.ptr.cast());

      if (FAILED(hr)) {
        final exception = WindowsException(hr);
        Get.log(exception.convertWindowsErrorToString(hr));

        CoUninitialize();
        throw exception;
      }

      final proxy = calloc<Pointer<COMObject>>();

      hr = pLoc.connectServer(
        TEXT('ROOT\\CIMV2'),
        nullptr,
        nullptr,
        nullptr,
        NULL,
        nullptr,
        nullptr,
        proxy,
      );

      if (FAILED(hr)) {
        final exception = WindowsException(hr);
        Get.log(exception.convertWindowsErrorToString(hr));
        CoUninitialize();
        throw exception;
      }

      final pSvc = IWbemServices(proxy.cast());

      hr = CoSetProxyBlanket(
        proxy.value,
        RPC_C_AUTHN_WINNT,
        RPC_C_AUTHZ_NONE,
        nullptr,
        RPC_C_AUTHN_LEVEL.RPC_C_AUTHN_LEVEL_CALL,
        RPC_C_IMP_LEVEL.RPC_C_IMP_LEVEL_IMPERSONATE,
        nullptr,
        EOLE_AUTHENTICATION_CAPABILITIES.EOAC_NONE,
      );

      if (FAILED(hr)) {
        final exception = WindowsException(hr);
        Get.log(exception.convertWindowsErrorToString(hr));
        CoUninitialize();
        throw exception;
      }

      final pEnumerator = calloc<Pointer<COMObject>>();
      IEnumWbemClassObject enumerator;

      hr = pSvc.execQuery(
          TEXT('WQL'),
          TEXT('SELECT * FROM Win32_PerfFormattedData_Tcpip_NetworkInterface'),
          WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_FORWARD_ONLY |
              WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_RETURN_IMMEDIATELY,
          nullptr,
          pEnumerator);

      if (FAILED(hr)) {
        final exception = WindowsException(hr);
        Get.log(exception.convertWindowsErrorToString(hr));

        CoUninitialize();

        throw exception;
      } else {
        enumerator = IEnumWbemClassObject(pEnumerator.cast());

        Pointer<Uint32> uReturn = calloc<Uint32>();

        double maxDownloadSpeed = -1;

        while (enumerator.ptr.address > 0) {
          final pClsObj = calloc<IntPtr>();

          hr = enumerator.next(WBEM_INFINITE, 1, pClsObj.cast(), uReturn);

          if (uReturn.value == 0) break;

          final clsObj = IWbemClassObject(pClsObj.cast());

          final vtProp = calloc<VARIANT>();
          hr = clsObj.get(
              TEXT('BytesReceivedPersec'), 0, vtProp, nullptr, nullptr);
          if (SUCCEEDED(hr)) {
            final String strValue = vtProp.ref.bstrVal.toDartString();
            final double? dValue = double.tryParse(strValue);
            if (dValue != null && maxDownloadSpeed < dValue) {
              maxDownloadSpeed = dValue / 1024;
            }
          }
        }
        webSocket.send(
          json.encode(
            {
              "type": "NETWORK_BANDWITH",
              "value": "${maxDownloadSpeed.floor()} KB/s"
            },
          ),
        );
      }
      CoUninitialize();
    } catch (e, stack) {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to send network bandwith (ERROR) - $e",
          isError: true);
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to send network bandwith (STACK) - $stack",
          isError: true);
    }
  }

  static void _sendCPUTemp(WebSocket webSocket) {
    var hr = CoInitializeEx(nullptr, COINIT.COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) throw WindowsException(hr);

    final pLoc = IWbemLocator(calloc<COMObject>());

    final clsid = calloc<GUID>()..ref.setGUID(CLSID_WbemLocator);
    final iid = calloc<GUID>()..ref.setGUID(IID_IWbemLocator);

    hr = CoCreateInstance(
        clsid, nullptr, CLSCTX.CLSCTX_INPROC_SERVER, iid, pLoc.ptr.cast());

    if (FAILED(hr)) {
      final exception = WindowsException(hr);
      Get.log(exception.convertWindowsErrorToString(hr));

      CoUninitialize();
      throw exception;
    }

    final proxy = calloc<Pointer<COMObject>>();

    hr = pLoc.connectServer(
      TEXT('ROOT\\CIMV2'),
      nullptr,
      nullptr,
      nullptr,
      NULL,
      nullptr,
      nullptr,
      proxy,
    );

    if (FAILED(hr)) {
      final exception = WindowsException(hr);
      Get.log(exception.convertWindowsErrorToString(hr));
      CoUninitialize();
      throw exception;
    }

    final pSvc = IWbemServices(proxy.cast());

    hr = CoSetProxyBlanket(
      proxy.value,
      RPC_C_AUTHN_WINNT,
      RPC_C_AUTHZ_NONE,
      nullptr,
      RPC_C_AUTHN_LEVEL.RPC_C_AUTHN_LEVEL_CALL,
      RPC_C_IMP_LEVEL.RPC_C_IMP_LEVEL_IMPERSONATE,
      nullptr,
      EOLE_AUTHENTICATION_CAPABILITIES.EOAC_NONE,
    );

    if (FAILED(hr)) {
      final exception = WindowsException(hr);
      Get.log(exception.convertWindowsErrorToString(hr));
      CoUninitialize();
      throw exception;
    }

    final pEnumerator = calloc<Pointer<COMObject>>();
    IEnumWbemClassObject enumerator;

    hr = pSvc.execQuery(
        TEXT('WQL'),
        TEXT(
            'SELECT * FROM Win32_PerfFormattedData_Counters_ThermalZoneInformation'),
        WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_FORWARD_ONLY |
            WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_RETURN_IMMEDIATELY,
        nullptr,
        pEnumerator);

    if (FAILED(hr)) {
      final exception = WindowsException(hr);
      Get.log(exception.convertWindowsErrorToString(hr));

      CoUninitialize();

      throw exception;
    } else {
      enumerator = IEnumWbemClassObject(pEnumerator.cast());

      final uReturn = calloc<Uint32>();

      while (enumerator.ptr.address > 0) {
        final pClsObj = calloc<IntPtr>();

        hr = enumerator.next(WBEM_INFINITE, 1, pClsObj.cast(), uReturn);

        if (uReturn.value == 0) break;

        final clsObj = IWbemClassObject(pClsObj.cast());

        final vtProp = calloc<VARIANT>();
        hr = clsObj.get(TEXT('Temperature'), 0, vtProp, nullptr, nullptr);

        if (SUCCEEDED(hr)) {
          webSocket.send(
            json.encode(
              {
                "type": "CPU_TEMPERATURE",
                "value": "${(vtProp.ref.intVal - 273.15).floor()} C",
              },
            ),
          );
        }
        VariantClear(vtProp);
        free(vtProp);
      }
    }
    CoUninitialize();
  }

  static void _sendGPUTemp(WebSocket webSocket) async {
    final processResult =
        Process.runSync("nvidia-smi", ["-q", "--id=0", "-d", "TEMPERATURE"]);
    final String strResult =
        processResult.stdout.toString().replaceAll(" ", "");
    Match? m = RegExp(r'GPUCurrentTemp:(\d+)').firstMatch(strResult);
    if (m != null) {
      webSocket.send(
        json.encode(
          {
            "type": "GPU_TEMPERATURE",
            "value": "${m.group(1)} C",
          },
        ),
      );
    }
  }

  static void _sendBatteryInfo(WebSocket webSocket) {
    final lpSystemPowerStatus = calloc<SYSTEM_POWER_STATUS>();
    final hr = GetSystemPowerStatus(lpSystemPowerStatus);

    if (SUCCEEDED(hr)) {
      if (lpSystemPowerStatus.ref.BatteryFlag < 128) {
        final batteryRemainingPercent =
            lpSystemPowerStatus.ref.BatteryLifePercent;
        if (batteryRemainingPercent <= 100) {
          webSocket.send(
            json.encode(
              {"type": "BATTERY_STATUS", "value": "$batteryRemainingPercent %"},
            ),
          );
        }
      }
      free(lpSystemPowerStatus);
    }
  }

  Future<void> onPlayButtonPress() async {
    isProcessOn.toggle();
    showLoadingActivity.value = isProcessOn.value;
    if (isProcessOn.value) {
      _executeProcess();
    }
  }

  Future<void> _process() async {
    if (await _takeCapture() == true) {
      Get.log("[INFO - ${DateTime.now()}] Screenshot taken");
      final Uint8List? compressedCapture = await _compressCapture();
      if (compressedCapture != null) {
        _uploadCapture(compressedCapture);
      }
    }
  }

  Future<void> _executeProcess() async {
    try {
      progressIndicatorValue.value = null;
      Get.log("[INFO - ${DateTime.now()}] Executing process...");
      _taskCompleter ??= Completer();
      await _process();
      await _taskCompleter?.future;
      _taskCompleter = null;
      Get.log("[INFO - ${DateTime.now()}] Process finished, starting timer...");
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isProcessOn.value) {
          int uploadTime = int.parse(uploadTimerInitialValue.value);
          if (timer.tick % uploadTime == 0) {
            progressIndicatorValue.value = 1.0;
            timer.cancel();
            Get.log(
                "[INFO - ${DateTime.now()}] $uploadTime seconds have passed, canceled timer and now restarting process...");
            _executeProcess();
          } else {
            progressIndicatorValue.value =
                (timer.tick % uploadTime) / uploadTime;
          }
        } else {
          showLoadingActivity.value = false;
          progressIndicatorValue.value = null;
          Get.log("[INFO - ${DateTime.now()}] Process stopped by user");
          timer.cancel();
        }
      });
    } catch (e, stack) {
      progressIndicatorValue.value = null;
      showLoadingActivity.value = false;
      isProcessOn.value = false;
      Get.log(
          "[ERROR - ${DateTime.now()}] Something went wrong with the process (ERROR) - $e");
      Get.log(
          "[ERROR - ${DateTime.now()}] Something went wrong with the process (STACK) - $stack");
    }
  }

  Future<bool> _takeCapture() async {
    final ProcessResult result =
        await Process.run("screenCap.exe", ["ss.png"], runInShell: true);
    if (result.exitCode != 0 || result.stderr.isNotEmpty) {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to take screenshot (ERROR) - ${result.stderr}");
      return false;
    }
    return true;
  }

  Future<Uint8List?> _compressCapture() async {
    File capture = File("ss.png");
    if (await capture.exists()) {
      final input = ImageFile(
          filePath: capture.path, rawBytes: capture.readAsBytesSync());
      final output = await compressInQueue(
        ImageFileConfiguration(
          input: input,
          config: const Configuration(
              outputType: OutputType.png,
              pngCompression: PngCompression.bestCompression),
        ),
      );
      capture.writeAsBytesSync(output.rawBytes);
      return output.rawBytes;
    } else {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to compress capture - File does not exist");
    }
    return null;
  }

  _uploadCapture(Uint8List capture) {
    Get.log("[INFO - ${DateTime.now()}] Uploading capture");
    webSocket.send(json.encode({
      "type": "CAPTURE_UPLOAD",
      "capture": base64Encode(capture),
    }));
  }

  _downloadCapture(String url) async {
    final response =
        await http.Client().send(http.Request('GET', Uri.parse(url)));
    final totalBytes = response.contentLength ?? 0;
    final List<int> downloadedBytes = [];
    response.stream.listen((value) {
      if (totalBytes != 0) {
        progressIndicatorValue.value = downloadedBytes.length / totalBytes;
      }
      downloadedBytes.addAll(value);
    }, onDone: () {
      latestCapture.value = Uint8List.fromList(downloadedBytes);
      if (!isProcessOn.value) {
        showLoadingActivity.value = false;
        progressIndicatorValue.value = null;
      }
      _taskCompleter?.complete();
    }, onError: (error) {
      _taskCompleter?.complete();
      if (!isProcessOn.value) {
        showLoadingActivity.value = false;
        progressIndicatorValue.value = null;
      }
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to download capture - $error");
    });
  }

  // Settings related methods
  Future<void> onUploadTimerSaveClick() async {
    try {
      if (uploadTimerController.text.isNotEmpty) {
        int uploadTime = int.parse(uploadTimerController.text);
        _updateUploadTimerTask = Completer();
        isUploadTimerSaveBtnLoading.value = true;
        _updateUploadTimer(uploadTime);
        await _updateUploadTimerTask!.future
            .timeout(const Duration(seconds: 30));
        uploadTimerInitialValue.value = "$uploadTime";
      }
    } catch (e, stack) {
      if (e is TimeoutException) {
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update upload timer (TIMEOUT)");
      } else {
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update upload timer (ERROR) - $e");
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update upload timer (STACK) - $stack");
      }
    } finally {
      isUploadTimerSaveBtnEnabled.value = false;
      isUploadTimerSaveBtnLoading.value = false;
    }
  }

  void _updateUploadTimer(int uploadTime) {
    webSocket.send(json.encode({
      "type": "UPDATE_UPLOAD_TIMER",
      "uploadTime": uploadTime,
    }));
  }

  Future<void> onUrgentTimerSaveClick() async {
    try {
      if (urgentActionTimerController.text.isNotEmpty) {
        int urgentTime = int.parse(urgentActionTimerController.text);
        _updateUrgentTimerTask = Completer();
        isUrgentTimerSaveBtnLoading.value = true;
        _updateUrgentTimer(urgentTime);
        await _updateUrgentTimerTask!.future
            .timeout(const Duration(seconds: 30));
        urgentActionTimerInitialValue.value = "$urgentTime";
      }
    } catch (e, stack) {
      if (e is TimeoutException) {
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update urgent timer (TIMEOUT)");
      } else {
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update urgent timer (ERROR) - $e");
        Get.log(
            "[ERROR - ${DateTime.now()}] Failed to update urgent timer (STACK) - $stack");
      }
    } finally {
      isUrgentTimerSaveBtnEnabled.value = false;
      isUrgentTimerSaveBtnLoading.value = false;
    }
  }

  void _updateUrgentTimer(int urgentTime) {
    webSocket.send(json.encode({
      "type": "UPDATE_URGENT_TIMER",
      "urgentTime": urgentTime,
    }));
  }

  Future<void> onShutdownSwitchClick(bool value) async {
    try {
      _updateIsUrgentActionActive(value);
      if (value) {
        if (urgentActionTimer != null) {
          urgentActionTimer?.cancel();
        }
        _shutdownUrgentActionTask = Completer();

        await _shutdownUrgentActionTask?.future;
      }
    } catch (e, stack) {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to update urgent action type (ERROR) - $e");
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to update urgent action type (STACK) - $stack");
    }
  }

  void _sendUrgentActionTimerTick() {
    webSocket.send(json.encode({
      "type": "URGENT_TIMER_TICK",
    }));
  }

  void _updateIsUrgentActionActive(bool value) {
    webSocket.send(json.encode({
      "type": "IS_URGENT_ACTION_ACTIVE",
      "isUrgentActionActive": value,
    }));
  }

  Future<void> _executeShutdown() async {
    final ProcessResult result =
        await Process.run("shutdown", ["/s"], runInShell: true);
    if (result.exitCode != 0 || result.stderr.isNotEmpty) {
      Get.log(
          "[ERROR - ${DateTime.now()}] Failed to shutdown PC (ERROR) - ${result.stderr}");
    }
    Get.log("[INFO - ${DateTime.now()}] PC should be shutting down now");
  }
}
