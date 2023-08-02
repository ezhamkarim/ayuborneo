import 'package:flutter/material.dart';

class ExceptionView extends StatelessWidget {
  const ExceptionView({Key? key, required this.routeName}) : super(key: key);
  final String routeName;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [Center(child: Text('Exception : $routeName not found'))]),
    );
  }
}
