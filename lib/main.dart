import 'package:flutter/material.dart';
import 'package:syncnotes/editor.dart';

void main() {
  runApp(const Syncnotes());
}

class Syncnotes extends StatelessWidget {
  const Syncnotes({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Editor(),
    );
  }
}
