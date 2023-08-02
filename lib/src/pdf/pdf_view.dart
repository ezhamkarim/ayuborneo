import 'dart:developer';
import 'dart:io';

import 'package:ayuborneo/src/pdf/example_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class InternalPdfView extends StatefulWidget {
  const InternalPdfView({super.key});
  static const routeName = '/output.pdf';
  @override
  State<InternalPdfView> createState() => _InternalPdfViewState();
}

class _InternalPdfViewState extends State<InternalPdfView> {
  String urlPDFPath = "";
  bool exists = true;
  int _totalPages = 0;
  int _currentPage = 0;
  bool pdfReady = false;
  late PDFViewController _pdfViewController;
  bool loaded = false;
  String error = '';
  Future<File?> getFileFromUrl(String url, {name}) async {
    var fileName = 'invoice';
    if (name != null) {
      fileName = name;
    }
    try {
      var data = await http.get(Uri.parse(url));
      var bytes = data.bodyBytes;
      var dir = await getApplicationDocumentsDirectory();
      File file = File("${dir.path}/$fileName.pdf");
      print('Dir path = ${dir.path}');
      File urlFile = await file.writeAsBytes(bytes);
      return urlFile;
    } catch (e) {
      log('Error : $error');
      error = e.toString();
      log('Err : $e');
      return null;
      // throw Exception("Error opening url file $e");
    }
  }

  void requestPersmission() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  @override
  void initState() {
    requestPersmission();
    getFileFromUrl(
      'https://ayuborneo.x1.com.my${InternalPdfView.routeName}',
    ).then((value) => {
          setState(() {
            if (value != null) {
              urlPDFPath = value.path;
              loaded = true;
              exists = true;
            } else {
              exists = false;
              loaded = false;
            }
          })
        });
    super.initState();
  }

  // Future<Set<void>> onError(e) async {
  //   loaded = false;
  //   exists = false;
  //   error = e.toString();

  //   log('Err : $e');
  //   var setvoid = {'test', 'hehe'};
  //   return setvoid;
  // }
  void dialogTest(String title) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            actions: [
              ElevatedButton(
                  style: ElevatedButton.styleFrom(elevation: 0),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Okay'))
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    print(urlPDFPath);
    if (loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF'), actions: [
          IconButton(
              onPressed: () async {
                Navigator.of(context).pushNamed(ExamplePrinterView.routeName,
                    arguments: urlPDFPath);
                // final pdf = File(urlPDFPath);
                // await Printing.layoutPdf(
                //         onLayout: (_) => pdf.readAsBytesSync(),
                //         name: 'Document Ayu Borneo')
                //     .catchError((e) {
                //   dialogTest('Warning $e');

                //   return false;
                // });
              },
              icon: const Icon(Icons.print))
        ]),
        body: PDFView(
          filePath: urlPDFPath,
          autoSpacing: true,
          enableSwipe: true,
          pageSnap: true,
          swipeHorizontal: true,
          nightMode: false,
          onError: (e) {
            //Show some error message or UI
          },
          onRender: (pages) {
            if (pages == null) return;
            setState(() {
              _totalPages = pages;
              pdfReady = true;
            });
          },
          onViewCreated: (PDFViewController vc) {
            setState(() {
              _pdfViewController = vc;
            });
          },
          onPageChanged: (int? page, int? total) {
            if (page == null) return;
            setState(() {
              _currentPage = page;
            });
          },
          onPageError: (page, e) {},
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              iconSize: 50,
              color: Colors.black,
              onPressed: () {
                setState(() {
                  if (_currentPage > 0) {
                    _currentPage--;
                    _pdfViewController.setPage(_currentPage);
                  }
                });
              },
            ),
            Text(
              "${_currentPage + 1}/$_totalPages",
              style: const TextStyle(color: Colors.black, fontSize: 20),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              iconSize: 50,
              color: Colors.black,
              onPressed: () {
                setState(() {
                  if (_currentPage < _totalPages - 1) {
                    _currentPage++;
                    _pdfViewController.setPage(_currentPage);
                  }
                });
              },
            ),
          ],
        ),
      );
    } else {
      if (exists) {
        //Replace with your loading UI
        return Scaffold(
          appBar: AppBar(
            title: const Text("Demo"),
          ),
          body: const Text(
            "Loading..",
            style: TextStyle(fontSize: 20),
          ),
        );
      } else {
        //Replace Error UI
        return Scaffold(
          appBar: AppBar(
            title: const Text("Demo"),
          ),
          body: Text(
            "PDF Not Available\n$error",
            style: const TextStyle(fontSize: 20),
          ),
        );
      }
    }
  }
}