import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:ayuborneo/src/log_helper.dart';
import 'package:ayuborneo/src/pdf/example_view.dart';
import 'package:ayuborneo/src/service/cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class InternalPdfView extends StatefulWidget {
  const InternalPdfView({super.key, this.query, this.path});
  final Map<String, String>? query;
  final String? path;
  static const routeName = '/output.pdf';
  @override
  State<InternalPdfView> createState() => _InternalPdfViewState();
}

class _InternalPdfViewState extends State<InternalPdfView> {
  final _client = http.Client();
  String urlPDFPath = "";
  bool exists = true;
  int _totalPages = 0;
  int _currentPage = 0;
  bool pdfReady = false;
  late PDFViewController _pdfViewController;
  bool loaded = false;
  String error = '';
  PdfPageSettings? pageSettings;
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

  Future<File?> postFile({
    required String url,
    required Map<String, String> body,
    name,
  }) async {
    var fileName = body['id'] ?? 'output';
    if (name != null) {
      fileName = name;
    }
    try {
      var data = await _client.post(Uri.parse(url),
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});
      var bytes = jsonDecode(data.body)['d'];
      List<int> newBytes = [];

      for (var byte in bytes) {
        newBytes.add(byte);
      }
      log('newBytes : ${newBytes.runtimeType}');

      var dir = await getApplicationDocumentsDirectory();
      File file = File("${dir.path}/$fileName.pdf");
      print('Dir path = ${dir.path}');
      File urlFile = await file.writeAsBytes(newBytes);

      final PdfDocument document =
          PdfDocument(inputBytes: urlFile.readAsBytesSync());

      final List<TextLine> textLine =
          PdfTextExtractor(document).extractTextLines();

      for (var i = 0; i < textLine.length; i++) {
        var text = textLine[i].text;
        logSuccess('i : $i, $text');
      }

      document.pageSettings.margins.all = 5;

      pageSettings = document.pageSettings;
      var urlFileUpdated = await File("${dir.path}/$fileName.pdf")
          .writeAsBytes(await document.save());
      return urlFileUpdated;
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

    var fromQuery = widget.query;

    if (fromQuery != null) {
      log(fromQuery.toString());
      var data = fromQuery['id'] ?? '';

      // var pdfData = int.tryParse(data);

      if (data.isEmpty) {
        loaded = true;
        exists = false;
        error = 'no id';

        return;
      }
      postFile(
        url: 'https://ayumobile.x1.com.my/ayudata.asmx/ConvertPdfToBinary',
        body: {'pdfData': data.toString()},
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
      return;
    }
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
              onPressed: () {
                DialogHelper.dialogWithOutActionWarning(
                  context,
                  'Delete Printer Setting',
                  okay: () {
                    CacheService.deleteCache('printer');
                    Navigator.of(context).pop();
                  },
                );
              },
              icon: const Icon(Icons.delete)),
          IconButton(
              onPressed: () {
                DialogHelper.dialogWithOutActionWarning(
                    context, 'Path : ${widget.path}, Param : ${widget.query}');
              },
              icon: const Icon(Icons.info)),
          IconButton(
              onPressed: () async {
                Navigator.of(context).pushNamed(ExamplePrinterView.routeName,
                    arguments: {
                      'urlPDFPath': urlPDFPath,
                      'pageSettings': pageSettings
                    });
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
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: PDFView(
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
          ),
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
