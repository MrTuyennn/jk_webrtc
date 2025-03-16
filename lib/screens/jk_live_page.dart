import 'package:flutter/widgets.dart';
import 'package:jk_webrtc/screens/live_page.dart';

class JkLivePage extends StatelessWidget {
  const JkLivePage({super.key, required this.peerId, required this.selfid});

  final String peerId;
  final String selfid;

  @override
  Widget build(BuildContext context) {
    return LivePage(peerId: peerId, selfId: selfid, usedatachannel: true);
  }
}
