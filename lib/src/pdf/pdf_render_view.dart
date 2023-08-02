import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_render/pdf_render_widgets.dart';

class PdfRenderView extends StatefulWidget {
  const PdfRenderView({super.key});
  static const routeName = '/output.pdf';
  @override
  State<PdfRenderView> createState() => _PdfRenderViewState();
}

class _PdfRenderViewState extends State<PdfRenderView> {
  PdfViewerController controller = PdfViewerController();

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
      print(dir.path);
      File urlFile = await file.writeAsBytes(bytes);
      return urlFile;
    } catch (e) {
      throw Exception("Error opening url file");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewer.openFutureFile(
      // Accepting function that returns Future<String> of PDF file path
      () async {
        var file = await getFileFromUrl('https://ayuborneo.x1.com.my${PdfRenderView.routeName}');

        if (file == null) {
          throw Exception('cannot get');
        }
        return file.path;
      },
      viewerController: controller,

      onError: (err) => print(err),
      params: const PdfViewerParams(
        padding: 10,
        minScale: 1.0,
        // scrollDirection: Axis.horizontal,
      ),
    );
  }
}
