import 'package:flutter/material.dart';

class TestView extends StatefulWidget {
  const TestView({super.key, required this.query});
  final Map<String, String> query;

  @override
  State<TestView> createState() => _TestViewState();
}

class _TestViewState extends State<TestView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(widget.query.toString()),
      ),
    );
  }
}
