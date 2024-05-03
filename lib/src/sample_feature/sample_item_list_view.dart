import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sample_item.dart';

/// Displays a list of SampleItems.
class SampleItemListView extends StatelessWidget {
  const SampleItemListView({
    super.key,
    this.items = const [SampleItem(1), SampleItem(2), SampleItem(3)],
  });

  static const routeName = '/';

  final List<SampleItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Ayuborne Testing'),
        ),

        // To work with lists that may contain a large number of items, it’s best
        // to use the ListView.builder constructor.
        //
        // In contrast to the default ListView constructor, which requires
        // building all Widgets up front, the ListView.builder constructor lazily
        // builds Widgets as they’re scrolled into view.
        body: Center(
          child: ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse('https://ayuborneo.x1.com.my/output.pdf'),
                    mode: LaunchMode.externalNonBrowserApplication);
              },
              child: const Text('Open PDF From App')),
        ));
  }
}
