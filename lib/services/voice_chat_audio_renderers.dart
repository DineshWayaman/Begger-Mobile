import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// This widget should be in your widget tree (can be offscreen/invisible for audio-only).
class VoiceChatAudioRenderers extends StatelessWidget {
  final Map<String, RTCVideoRenderer> remoteRenderers;
  const VoiceChatAudioRenderers({required this.remoteRenderers, super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: remoteRenderers.entries.map((entry) {
        return SizedBox(
          width: 0, height: 0, // invisible, but keeps audio alive
          child: RTCVideoView(entry.value, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,),
        );
      }).toList(),
    );
  }
}