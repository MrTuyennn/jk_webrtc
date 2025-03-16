import 'package:flutter/material.dart';
import 'package:jk_webrtc/jk_webrtc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JK_Webrtc'),
      ),
      body: const JkWebrtc(
        peerId: "RHZL-KVFH-TAX2-00000001",
        selfid: "9b6d4c9f-7813-475f-aae6-263ae92f97a1",
      ),
    );
  }
}
