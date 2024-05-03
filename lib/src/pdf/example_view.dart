// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:ayuborneo/src/log_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:printing/printing.dart';

import 'package:ayuborneo/src/service/cache_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ExamplePrinterView extends StatefulWidget {
  const ExamplePrinterView({
    super.key,
    this.filePath,
    required this.pageSettings,
  });
  final PdfPageSettings pageSettings;
  final String? filePath;
  static const routeName = '/example-print';
  @override
  State<ExamplePrinterView> createState() => _ExamplePrinterViewState();
}

class _ExamplePrinterViewState extends State<ExamplePrinterView> {
  // Printer Type [bluetooth, usb, network]
  var defaultPrinterType = PrinterType.usb;
  var _isBle = false;
  var _reconnect = false;
  var _isConnected = false;
  var printerManager = PrinterManager.instance;
  var devices = <Printer>[];
  final dpiTextController = TextEditingController();
  StreamSubscription<PrinterDevice>? _subscription;
  StreamSubscription<BTStatus>? _subscriptionBtStatus;
  StreamSubscription<USBStatus>? _subscriptionUsbStatus;
  BTStatus _currentStatus = BTStatus.none;
  // _currentUsbStatus is only supports on Android
  // ignore: unused_field
  USBStatus _currentUsbStatus = USBStatus.none;
  List<int>? pendingTask;
  String _ipAddress = '';
  String? capabilityProfile;
  String _port = '9100';
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  Printer? selectedPrinter;
  double printerDpi = 200.0;
  // double ratio = 2947;
  List<CapabilityProfileItem> cpItems = [];
  CapabilityProfileItem? selectedCapabilities;
  String capability = 'default';
  bool isLoading = false;
  @override
  void initState() {
    // var ps = widget.pageSettings;

    // printerDpi = (ps.size.height * ps.size.width) / ratio;

    dpiTextController.text = printerDpi.toString();
    if (Platform.isWindows) defaultPrinterType = PrinterType.usb;
    super.initState();
    _portController.text = _port;
    _scan();

    // subscription to listen change status of bluetooth connection
    _subscriptionBtStatus =
        PrinterManager.instance.stateBluetooth.listen((status) {
      log(' ----------------- status bt $status ------------------ ');
      _currentStatus = status;
      if (status == BTStatus.connected) {
        setState(() {
          _isConnected = true;
        });
      }
      if (status == BTStatus.none) {
        setState(() {
          _isConnected = false;
        });
      }
      if (status == BTStatus.connected && pendingTask != null) {
        if (Platform.isAndroid) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance
                .send(type: PrinterType.bluetooth, bytes: pendingTask!);
            pendingTask = null;
          });
        } else if (Platform.isIOS) {
          PrinterManager.instance
              .send(type: PrinterType.bluetooth, bytes: pendingTask!);
          pendingTask = null;
        }
      }
    });
    //  PrinterManager.instance.stateUSB is only supports on Android
    _subscriptionUsbStatus = PrinterManager.instance.stateUSB.listen((status) {
      log(' ----------------- status usb $status ------------------ ');
      _currentUsbStatus = status;
      if (Platform.isAndroid) {
        if (status == USBStatus.connected && pendingTask != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance
                .send(type: PrinterType.usb, bytes: pendingTask!);
            pendingTask = null;
          });
        }
      }
    });

    _readFromCacheAndPrint();
  }

  void _readFromCacheAndPrint() async {
    try {
      setState(() {
        isLoading = true;
      });
      var data = await CacheService.readCache('printer');
      logSuccess('Cached Printer : $data');
      if (data == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      var cachePrinter = Printer.fromJson(data);
      _scan();
      selectDevice(cachePrinter);
      _connectDevice(save: false);
      setState(() {
        defaultPrinterType = cachePrinter.typePrinter;
      });

      await _printReceiveTest();
      setState(() {
        isLoading = false;
      });
      _scan();
      return;
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      DialogHelper.dialogWithOutActionWarning(context, 'e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscriptionBtStatus?.cancel();
    _subscriptionUsbStatus?.cancel();
    _portController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  // method to scan devices according PrinterType
  void _scan() {
    devices.clear();
    cpItems.clear();
    _subscription = printerManager
        .discovery(type: defaultPrinterType, isBle: _isBle)
        .listen((device) {
      bool added = false;
      for (var element in devices) {
        if (element.deviceName == device.name ||
            element.vendorId == device.productId) {
          added = true;
          break;
        }
      }

      if (added == false) {
        devices.add(Printer(
          deviceName: device.name,
          address: device.address,
          isBle: _isBle,
          vendorId: device.vendorId,
          productId: device.productId,
          typePrinter: defaultPrinterType,
        ));
      }
      setState(() {});
    });
  }

  void setPort(String value) {
    if (value.isEmpty) value = '9100';
    _port = value;
    var device = Printer(
      deviceName: value,
      address: _ipAddress,
      port: _port,
      typePrinter: PrinterType.network,
      state: false,
    );
    selectDevice(device);
  }

  void setIpAddress(String value) {
    _ipAddress = value;
    var device = Printer(
      deviceName: value,
      address: _ipAddress,
      port: _port,
      typePrinter: PrinterType.network,
      state: false,
    );
    selectDevice(device);
  }

  void selectDevice(Printer device, {bool callSetState = true}) async {
    if (selectedPrinter != null) {
      if ((device.address != selectedPrinter!.address) ||
          (device.typePrinter == PrinterType.usb &&
              selectedPrinter!.vendorId != device.vendorId)) {
        await PrinterManager.instance
            .disconnect(type: selectedPrinter!.typePrinter);
      }
    }

    selectedPrinter = device;
    if (callSetState) setState(() {});
  }

  Future getCapabilityProfiles() async {
    try {
      var cp = await CapabilityProfile.getAvailableProfiles();

      for (var profile in cp) {
        cpItems.add(CapabilityProfileItem.fromMap(profile));
      }
    } catch (e) {
      if (context.mounted) {
        DialogHelper.dialogWithOutActionWarning(
            context, 'Cant get capability $e');
      }
    }
  }

  Future _printReceiveTest() async {
    try {
      setState(() {
        isLoading = true;
      });
      // if (selectedCapabilities == null) {
      //   if (context.mounted) {
      //     dialogWithOutActionWarning(context, 'Please select capabilities');
      //   }
      //   return;
      // }
      List<int> bytes = [];

      // Xprinter XP-N160I
      final profile = await CapabilityProfile.load(name: capability);

      // PaperSize.mm80 or PaperSize.mm58
      final generator = Generator(PaperSize.mm56, profile);
      // bytes += generator.setGlobalCodeTable('CP1252');

      var filePath = widget.filePath;

      if (filePath == null) {
        // bytes += generator.text('Test Print',
        //     styles: const PosStyles(align: PosAlign.center));
        // bytes += generator.text('Product 1');
        // bytes += generator.text('Product 2');

        if (context.mounted) {
          DialogHelper.dialogWithOutActionWarning(context, 'Cant print');
        }
        setState(() {
          isLoading = false;
        });
        return;
      }

      var ticket = <int>[];

      var raster =
          Printing.raster(File(filePath).readAsBytesSync(), dpi: printerDpi);
      await for (var page in raster) {
        final image = page.asImage();

        ticket += generator.image(image);
        ticket += generator.feed(1);
        ticket += generator.cut();
      }

      bytes += ticket;
      bytes += generator.cut(mode: PosCutMode.partial, emptyLine: 2);
      await _printEscPos(bytes, generator);
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (context.mounted) {
        DialogHelper.dialogWithOutActionWarning(context, 'Cant print $e');
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  /// print ticket
  Future<void> _printEscPos(List<int> bytes, Generator generator) async {
    if (selectedPrinter == null) return;
    var bluetoothPrinter = selectedPrinter!;

    switch (bluetoothPrinter.typePrinter) {
      case PrinterType.usb:
        // bytes += generator.feed(2);
        // bytes += generator.cut();
        await printerManager.connect(
            type: bluetoothPrinter.typePrinter,
            model: UsbPrinterInput(
                name: bluetoothPrinter.deviceName,
                productId: bluetoothPrinter.productId,
                vendorId: bluetoothPrinter.vendorId));
        pendingTask = null;
        break;
      case PrinterType.bluetooth:
        // bytes += generator.cut();
        await printerManager.connect(
            type: bluetoothPrinter.typePrinter,
            model: BluetoothPrinterInput(
                name: bluetoothPrinter.deviceName,
                address: bluetoothPrinter.address!,
                isBle: bluetoothPrinter.isBle ?? false,
                autoConnect: _reconnect));
        pendingTask = null;
        if (Platform.isAndroid) pendingTask = bytes;
        break;
      case PrinterType.network:
        bytes += generator.feed(2);
        bytes += generator.cut();
        await printerManager.connect(
            type: bluetoothPrinter.typePrinter,
            model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!));
        break;
      default:
    }
    if (bluetoothPrinter.typePrinter == PrinterType.bluetooth &&
        Platform.isAndroid) {
      if (_currentStatus == BTStatus.connected) {
        await printerManager.send(
            type: bluetoothPrinter.typePrinter, bytes: bytes);
        pendingTask = null;
      }
    } else {
      await printerManager.send(
          type: bluetoothPrinter.typePrinter, bytes: bytes);
    }
  }

  // conectar dispositivo
  _connectDevice({bool callSetState = true, bool save = true}) async {
    _isConnected = false;
    if (selectedPrinter == null) return;
    switch (selectedPrinter!.typePrinter) {
      case PrinterType.usb:
        await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: UsbPrinterInput(
                name: selectedPrinter!.deviceName,
                productId: selectedPrinter!.productId,
                vendorId: selectedPrinter!.vendorId));
        _isConnected = true;
        break;
      case PrinterType.bluetooth:
        await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: BluetoothPrinterInput(
                name: selectedPrinter!.deviceName,
                address: selectedPrinter!.address!,
                isBle: selectedPrinter!.isBle ?? false,
                autoConnect: _reconnect));
        break;
      case PrinterType.network:
        await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: TcpPrinterInput(ipAddress: selectedPrinter!.address!));
        _isConnected = true;
        break;
      default:
    }
    await getCapabilityProfiles();
    if (callSetState) setState(() {});

    if (save) {
      await CacheService.createCache('printer', selectedPrinter!.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Print'),
          actions: [
            IconButton(
                onPressed: () {
                  CacheService.deleteCache('printer');
                },
                icon: const Icon(Icons.delete)),
            IconButton(
                onPressed: () {
                  var ps = widget.pageSettings;
                  var ratio = (ps.size.height * ps.size.width) / printerDpi;
                  DialogHelper.dialogWithOutActionWarning(context, 'Info',
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        // shrinkWrap: true,
                        children: [
                          Text('Height : ${ps.height}'),
                          const SizedBox(
                            height: 16,
                          ),
                          Text('Width : ${ps.width}'),
                          const SizedBox(
                            height: 16,
                          ),
                          Text('Margin top : ${ps.margins.top}'),
                          const SizedBox(
                            height: 16,
                          ),
                          Text('Margin Bottom : ${ps.margins.bottom}'),
                          const SizedBox(
                            height: 16,
                          ),
                          Text('Margin left : ${ps.margins.left}'),
                          const SizedBox(
                            height: 16,
                          ),
                          Text('Margin Right : ${ps.margins.right}'),
                          const SizedBox(
                            height: 16,
                          ),
                          Text('Size : ${ps.size}'),
                          const SizedBox(
                            height: 16,
                          ),
                          Text('Ratio : $ratio'),
                          const SizedBox(
                            height: 16,
                          ),
                        ],
                      ));
                },
                icon: const Icon(Icons.info)),
            PopupMenuButton<String>(
              padding: const EdgeInsets.all(0),
              onSelected: (index) async {
                switch (index) {
                  case 'XP-N160I':
                    setState(() {
                      capability = 'XP-N160I';
                    });
                    break;
                  case 'RP80USE':
                    setState(() {
                      capability = 'RP80USE';
                    });
                    break;
                  case 'SUNMI':
                    setState(() {
                      capability = 'SUNMI';
                    });
                    break;
                  case 'TP806L':
                    setState(() {
                      capability = 'TP806L';
                    });
                    break;
                  default:
                }
              },
              icon: const Icon(
                Icons.filter,
                size: 18,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                    onTap: () {
                      setState(() {
                        capability = 'XP-N160I';
                      });
                    },
                    value: 'XP-N160I',
                    child: const Text('XP-N160I')),
                PopupMenuItem(
                    onTap: () {
                      setState(() {
                        capability = 'RP80USE';
                      });
                    },
                    value: 'RP80USE',
                    child: const Text('RP80USE')),
                PopupMenuItem(
                    onTap: () {
                      setState(() {
                        capability = 'SUNMI';
                      });
                    },
                    value: 'SUNMI',
                    child: const Text('SUNMI')),
                PopupMenuItem(
                    onTap: () {
                      setState(() {
                        capability = 'TP806L';
                      });
                    },
                    value: 'TP806L',
                    child: const Text('TP806L')),
              ],
            )
          ],
        ),
        body: Center(
          child: isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Printing in progress...'),
                    const SizedBox(
                      height: 18,
                    ),
                    const Text('Select other printer?'),
                    const SizedBox(
                      height: 18,
                    ),
                    OutlinedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = false;
                          });
                        },
                        child: const Text('Select'))
                  ],
                )
              : Container(
                  height: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      selectedPrinter == null || _isConnected
                                          ? null
                                          : () {
                                              _connectDevice();
                                            },
                                  child: const Text("Connect",
                                      textAlign: TextAlign.center),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: selectedPrinter == null ||
                                          !_isConnected
                                      ? null
                                      : () async {
                                          if (selectedPrinter != null) {
                                            await printerManager.disconnect(
                                                type: selectedPrinter!
                                                    .typePrinter);
                                            CacheService.deleteCache('printer');
                                          }
                                          setState(() {
                                            selectedPrinter = null;
                                            _isConnected = false;
                                          });
                                        },
                                  child: const Text("Disconnect",
                                      textAlign: TextAlign.center),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonFormField<PrinterType>(
                          value: defaultPrinterType,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.print,
                              size: 24,
                            ),
                            labelText: "Type Printer Device",
                            labelStyle: TextStyle(fontSize: 18.0),
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                          ),
                          items: <DropdownMenuItem<PrinterType>>[
                            if (Platform.isAndroid || Platform.isIOS)
                              const DropdownMenuItem(
                                value: PrinterType.bluetooth,
                                child: Text("bluetooth"),
                              ),
                            if (Platform.isAndroid || Platform.isWindows)
                              const DropdownMenuItem(
                                value: PrinterType.usb,
                                child: Text("usb"),
                              ),
                            const DropdownMenuItem(
                              value: PrinterType.network,
                              child: Text("Wifi"),
                            ),
                          ],
                          onChanged: (PrinterType? value) {
                            setState(() {
                              if (value != null) {
                                setState(() {
                                  defaultPrinterType = value;
                                  selectedPrinter = null;
                                  _isBle = false;
                                  _isConnected = false;
                                  _scan();
                                });
                              }
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Capability : $capability'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'DPI Printer'),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp("[0-9]"))
                            ],
                            controller: dpiTextController,
                            onChanged: (value) {
                              var val = double.tryParse(value);

                              if (val == null) return;
                              setState(() {
                                printerDpi = val;
                              });
                            },
                          ),
                        ),
                        // Visibility(
                        //     visible: _isConnected,
                        //     child: DropdownButtonFormField<CapabilityProfileItem>(
                        //         value: selectedCapabilities,
                        //         items: cpItems
                        //             .map((e) =>
                        //                 DropdownMenuItem<CapabilityProfileItem>(
                        //                     child: Text('${e.key}(${e.model})')))
                        //             .toList(),
                        //         onChanged: (val) {
                        //           if (val == null) return;
                        //           setState(() {
                        //             selectedCapabilities = val;
                        //           });
                        //         })),
                        Visibility(
                          visible:
                              defaultPrinterType == PrinterType.bluetooth &&
                                  Platform.isAndroid,
                          child: SwitchListTile.adaptive(
                            contentPadding:
                                const EdgeInsets.only(bottom: 20.0, left: 20),
                            title: const Text(
                              "This device supports ble (low energy)",
                              textAlign: TextAlign.start,
                              style: TextStyle(fontSize: 19.0),
                            ),
                            value: _isBle,
                            onChanged: (bool? value) {
                              setState(() {
                                _isBle = value ?? false;
                                _isConnected = false;
                                selectedPrinter = null;
                                _scan();
                              });
                            },
                          ),
                        ),
                        Visibility(
                          visible:
                              defaultPrinterType == PrinterType.bluetooth &&
                                  Platform.isAndroid,
                          child: SwitchListTile.adaptive(
                            contentPadding:
                                const EdgeInsets.only(bottom: 20.0, left: 20),
                            title: const Text(
                              "reconnect",
                              textAlign: TextAlign.start,
                              style: TextStyle(fontSize: 19.0),
                            ),
                            value: _reconnect,
                            onChanged: (bool? value) {
                              setState(() {
                                _reconnect = value ?? false;
                              });
                            },
                          ),
                        ),
                        Column(
                            children: devices
                                .map(
                                  (device) => ListTile(
                                    title: Text('${device.deviceName}'),
                                    subtitle: Platform.isAndroid &&
                                            defaultPrinterType ==
                                                PrinterType.usb
                                        ? null
                                        : Visibility(
                                            visible: !Platform.isWindows,
                                            child: Text("${device.address}")),
                                    onTap: () {
                                      // do something
                                      selectDevice(device);
                                    },
                                    leading: selectedPrinter != null &&
                                            ((device.typePrinter ==
                                                            PrinterType.usb &&
                                                        Platform.isWindows
                                                    ? device.deviceName ==
                                                        selectedPrinter!
                                                            .deviceName
                                                    : device.vendorId != null &&
                                                        selectedPrinter!
                                                                .vendorId ==
                                                            device.vendorId) ||
                                                (device.address != null &&
                                                    selectedPrinter!.address ==
                                                        device.address))
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          )
                                        : null,
                                    trailing: OutlinedButton(
                                      onPressed: selectedPrinter == null ||
                                              device.deviceName !=
                                                  selectedPrinter?.deviceName
                                          ? null
                                          : () async {
                                              _printReceiveTest();
                                            },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 20),
                                        child: Text("Print",
                                            textAlign: TextAlign.center),
                                      ),
                                    ),
                                  ),
                                )
                                .toList()),
                        Visibility(
                          visible: defaultPrinterType == PrinterType.network &&
                              Platform.isWindows,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: TextFormField(
                              controller: _ipController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      signed: true),
                              decoration: const InputDecoration(
                                label: Text("Ip Address"),
                                prefixIcon: Icon(Icons.wifi, size: 24),
                              ),
                              onChanged: setIpAddress,
                            ),
                          ),
                        ),
                        Visibility(
                          visible: defaultPrinterType == PrinterType.network &&
                              Platform.isWindows,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: TextFormField(
                              controller: _portController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      signed: true),
                              decoration: const InputDecoration(
                                label: Text("Port"),
                                prefixIcon:
                                    Icon(Icons.numbers_outlined, size: 24),
                              ),
                              onChanged: setPort,
                            ),
                          ),
                        ),
                        Visibility(
                          visible: defaultPrinterType == PrinterType.network &&
                              Platform.isWindows,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: OutlinedButton(
                              onPressed: () async {
                                if (_ipController.text.isNotEmpty) {
                                  setIpAddress(_ipController.text);
                                }
                                _printReceiveTest();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 50),
                                child: Text("Print test ticket",
                                    textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class CapabilityProfileItem {
  String key;
  String vendor;
  String model;
  String description;
  CapabilityProfileItem({
    required this.key,
    required this.vendor,
    required this.model,
    required this.description,
  });

  CapabilityProfileItem copyWith({
    String? key,
    String? vendor,
    String? model,
    String? description,
  }) {
    return CapabilityProfileItem(
      key: key ?? this.key,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'key': key,
      'vendor': vendor,
      'model': model,
      'description': description,
    };
  }

  factory CapabilityProfileItem.fromMap(Map<String, dynamic> map) {
    return CapabilityProfileItem(
      key: map['key'] as String,
      vendor: map['vendor'] as String,
      model: map['model'] as String,
      description: map['description'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory CapabilityProfileItem.fromJson(String source) =>
      CapabilityProfileItem.fromMap(
          json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'CapabilityProfileItem(key: $key, vendor: $vendor, model: $model, description: $description)';
  }

  @override
  bool operator ==(covariant CapabilityProfileItem other) {
    if (identical(this, other)) return true;

    return other.key == key &&
        other.vendor == vendor &&
        other.model == model &&
        other.description == description;
  }

  @override
  int get hashCode {
    return key.hashCode ^
        vendor.hashCode ^
        model.hashCode ^
        description.hashCode;
  }
}

class Printer {
  int? id;
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  bool? isBle;

  PrinterType typePrinter;
  bool? state;
  Printer({
    this.id,
    this.deviceName,
    this.address,
    this.port,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.bluetooth,
    this.isBle,
    this.state,
  });

  // Printer(
  //     {this.deviceName,
  //     this.address,
  //     this.port,
  //     this.state,
  //     this.vendorId,
  //     this.productId,
  //     this.typePrinter = PrinterType.bluetooth,
  //     this.isBle = false});

  Printer copyWith({
    int? id,
    String? deviceName,
    String? address,
    String? port,
    String? vendorId,
    String? productId,
    PrinterType? printerType,
    bool? isBle,
    bool? state,
  }) {
    return Printer(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      address: address ?? this.address,
      port: port ?? this.port,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      isBle: isBle ?? this.isBle,
      state: state ?? this.state,
      typePrinter: typePrinter,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'deviceName': deviceName,
      'address': address,
      'port': port,
      'vendorId': vendorId,
      'productId': productId,
      'isBle': isBle,
      'state': state,
      'typePrinter': typePrinter.toString(),
    };
  }

  factory Printer.fromMap(Map<String, dynamic> map) {
    return Printer(
        id: map['id'] != null ? map['id'] as int : null,
        deviceName:
            map['deviceName'] != null ? map['deviceName'] as String : null,
        address: map['address'] != null ? map['address'] as String : null,
        port: map['port'] != null ? map['port'] as String : null,
        vendorId: map['vendorId'] != null ? map['vendorId'] as String : null,
        productId: map['productId'] != null ? map['productId'] as String : null,
        isBle: map['isBle'] != null ? map['isBle'] as bool : null,
        state: map['state'] != null ? map['state'] as bool : null,
        typePrinter: getTypePrinter(map['typePrinter']));
  }

  String toJson() => json.encode(toMap());

  factory Printer.fromJson(String source) =>
      Printer.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Printer(id: $id, deviceName: $deviceName, address: $address, port: $port, vendorId: $vendorId, productId: $productId, isBle: $isBle, state: $state, PrinterType: $typePrinter)';
  }

  @override
  bool operator ==(covariant Printer other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.deviceName == deviceName &&
        other.address == address &&
        other.port == port &&
        other.vendorId == vendorId &&
        other.productId == productId &&
        other.isBle == isBle &&
        other.state == state &&
        other.typePrinter == typePrinter;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        deviceName.hashCode ^
        address.hashCode ^
        port.hashCode ^
        vendorId.hashCode ^
        productId.hashCode ^
        isBle.hashCode ^
        state.hashCode ^
        typePrinter.hashCode;
  }
}

PrinterType getTypePrinter(String str) {
  switch (str) {
    case 'PrinterType.usb':
      return PrinterType.usb;
    case 'PrinterType.network':
      return PrinterType.network;
    case 'PrinterType.bluetooth':
      return PrinterType.bluetooth;
    default:
      return PrinterType.usb;
  }
}

class DialogHelper {
  static Future dialogWithOutActionWarning(BuildContext context, String title,
      {Widget? widget, VoidCallback? okay}) {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: widget,
            actions: [
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      elevation: 0, backgroundColor: Colors.blue),
                  onPressed: okay ??
                      () {
                        Navigator.of(context).pop();
                      },
                  child: const Text('Okay'))
            ],
          );
        });
  }
}
