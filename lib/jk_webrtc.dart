library jk_webrtc;

import 'package:flutter/material.dart';
import 'package:jk_webrtc/screens/jk_live_page.dart';

class JkWebrtc extends StatelessWidget {
  const JkWebrtc({super.key, required this.peerId, required this.selfid});

  final String peerId;
  final String selfid;

  @override
  Widget build(BuildContext context) {
    return JkLivePage(peerId: peerId, selfid: selfid);
  }
}
