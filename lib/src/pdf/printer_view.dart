import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class PrinterView extends StatefulWidget {
  const PrinterView({super.key});
  static const routeName = '/printer';
  @override
  State<PrinterView> createState() => _PrinterViewState();
}

class _PrinterViewState extends State<PrinterView> {
  List<PrinterDevice> usbPrinter = [];

  List<PrinterDevice> bluetoothPrinter = [];

  List<PrinterDevice> nwPrinter = [];

  StreamSubscription<PrinterDevice>? usbPrinterSub;
  // Future<void> getPrinterInfo() async {
  //   var printer = await USBPrinterManager.discover();
  //   var nwPrinter = await NetworkPrinterManager.discover();

  //   log('Nw printer = ${nwPrinter.length}');
  //   log('USB printer = ${printer.length}');
  //   usbPrinter = printer;
  //   networkPrinter = nwPrinter;
  // }

  void getPrinter() {
    usbPrinterSub = PrinterManager.instance
        .discovery(type: PrinterType.usb, isBle: false)
        .listen((device) {
      setState(() {
        usbPrinter.add(device);
      });
    });
    PrinterManager.instance
        .discovery(type: PrinterType.bluetooth, isBle: true)
        .listen((device) {
      setState(() {
        bluetoothPrinter.add(device);
      });
    });

    PrinterManager.instance
        .discovery(type: PrinterType.network, isBle: false)
        .listen((device) {
      setState(() {
        nwPrinter.add(device);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   await getPrinterInfo();
    // });
  }

  @override
  void dispose() {
    super.dispose();

    usbPrinterSub?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ElevatedButton(onPressed: (){}, child: Text('Scan printer'))
            Column(
              children: [
                Text(('Usb printer count : ${usbPrinter.length}')),
                Text(('Network printer count : ${nwPrinter.length}')),
                Text(('Bluetooth printer count : ${bluetoothPrinter.length}')),
              ],
            ),
            ElevatedButton(
                onPressed: () {
                  getPrinter();
                },
                child: const Text('Search printer')),
            const SizedBox(
              height: 18,
            ),

            const Text('USB Printer'),
            const SizedBox(
              height: 8,
            ),
            usbPrinter.isEmpty
                ? const Text('No printer')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: usbPrinter.length,
                    itemBuilder: (c, i) {
                      var printer = usbPrinter[i];
                      return ListTile(
                        title: Text(printer.name ?? 'No Name'),
                      );
                    }),
            const SizedBox(
              height: 8,
            ),
            const Text('Network Printer'),
            const SizedBox(
              height: 8,
            ),
            nwPrinter.isEmpty
                ? const Text('No printer')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: nwPrinter.length,
                    itemBuilder: (c, i) {
                      var printer = nwPrinter[i];
                      return ListTile(
                        title: Text(printer.name),
                      );
                    }),
            const SizedBox(
              height: 8,
            ),
            const Text('Bluetooth Printer'),
            const SizedBox(
              height: 8,
            ),
            bluetoothPrinter.isEmpty
                ? const Text('No printer')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: bluetoothPrinter.length,
                    itemBuilder: (c, i) {
                      var printer = nwPrinter[i];
                      return ListTile(
                        title: Text(printer.name),
                      );
                    }),
          ],
        ),
      ),
    );
  }
}
