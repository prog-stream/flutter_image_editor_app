import 'package:flutter/material.dart';
import 'form_submission_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Form Submission with Drawing',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FormSubmissionScreen(),
    );
  }
}
