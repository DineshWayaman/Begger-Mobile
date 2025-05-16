import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:uuid/uuid.dart';
import '../services/websocket.dart';

class VoiceChatService with ChangeNotifier {
  final WebSocketService _webSocketService;
  final String gameId;
  final String playerId;
  Map<String, webrtc.RTCPeerConnection> peerConnections = {};
  webrtc.MediaStream? localStream;
  bool isMuted = false;
  final String connectionId = const Uuid().v4();
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  VoiceChatService(this._webSocketService, this.gameId, this.playerId) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      localStream = await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      debugPrint('Local audio stream initialized');
      notifyListeners();

      _webSocketService.socket.on('voiceSignal', (data) {
        _handleSignaling(data);
      });

      _webSocketService.socket.emit('joinVoice', {
        'gameId': gameId,
        'playerId': playerId,
        'connectionId': connectionId,
      });
    } catch (e) {
      debugPrint('Error initializing voice chat: $e');
    }
  }

  Future<void> createPeerConnection(String targetPlayerId, String targetConnectionId, {bool isOffer = false}) async {
    try {
      final peer = await webrtc.createPeerConnection(_iceServers, {});
      peerConnections[targetConnectionId] = peer;

      localStream?.getTracks().forEach((track) {
        peer.addTrack(track, localStream!);
      });

      peer.onIceCandidate = (webrtc.RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          _webSocketService.socket.emit('voiceSignal', {
            'gameId': gameId,
            'fromPlayerId': playerId,
            'fromConnectionId': connectionId,
            'toPlayerId': targetPlayerId,
            'toConnectionId': targetConnectionId,
            'type': 'ice',
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          });
        }
      };

      peer.onTrack = (webrtc.RTCTrackEvent event) {
        debugPrint('Received remote stream from $targetConnectionId');
      };

      if (isOffer) {
        final offer = await peer.createOffer();
        await peer.setLocalDescription(offer);
        _webSocketService.socket.emit('voiceSignal', {
          'gameId': gameId,
          'fromPlayerId': playerId,
          'fromConnectionId': connectionId,
          'toPlayerId': targetPlayerId,
          'toConnectionId': targetConnectionId,
          'type': 'offer',
          'sdp': offer.sdp,
        });
      }
    } catch (e) {
      debugPrint('Error creating peer connection: $e');
      rethrow; // Rethrow for debugging
    }
  }

  Future<void> _handleSignaling(Map<String, dynamic> data) async {
    final fromPlayerId = data['fromPlayerId'] as String?;
    final fromConnectionId = data['fromConnectionId'] as String?;
    final toConnectionId = data['toConnectionId'] as String?;
    final type = data['type'] as String?;

    if (type == null || fromPlayerId == null || fromConnectionId == null) {
      debugPrint('Invalid signaling data: $data');
      return;
    }

    // For newVoiceParticipant, toConnectionId is not required as it's a broadcast
    if (type != 'newVoiceParticipant' && toConnectionId == null) {
      debugPrint('Invalid signaling data (missing toConnectionId): $data');
      return;
    }

    // Verify toConnectionId for non-broadcast events
    if (type != 'newVoiceParticipant' && toConnectionId != connectionId) {
      return;
    }

    try {
      if (type == 'offer') {
        if (!peerConnections.containsKey(fromConnectionId)) {
          await createPeerConnection(fromPlayerId, fromConnectionId);
        }
        final peer = peerConnections[fromConnectionId]!;
        await peer.setRemoteDescription(webrtc.RTCSessionDescription(data['sdp'], 'offer'));
        final answer = await peer.createAnswer();
        await peer.setLocalDescription(answer);
        _webSocketService.socket.emit('voiceSignal', {
          'gameId': gameId,
          'fromPlayerId': playerId,
          'fromConnectionId': connectionId,
          'toPlayerId': fromPlayerId,
          'toConnectionId': fromConnectionId,
          'type': 'answer',
          'sdp': answer.sdp,
        });
      } else if (type == 'answer') {
        final peer = peerConnections[fromConnectionId];
        if (peer != null) {
          await peer.setRemoteDescription(webrtc.RTCSessionDescription(data['sdp'], 'answer'));
        }
      } else if (type == 'ice') {
        final peer = peerConnections[fromConnectionId];
        if (peer != null && data['candidate'] != null) {
          final candidate = webrtc.RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          );
          await peer.addCandidate(candidate);
        }
      } else if (type == 'newVoiceParticipant') {
        debugPrint('Processing new voice participant: $fromPlayerId ($fromConnectionId)');
        if (fromConnectionId != connectionId && !peerConnections.containsKey(fromConnectionId)) {
          await createPeerConnection(fromPlayerId, fromConnectionId, isOffer: true);
          debugPrint('Initiated peer connection for new participant: $fromPlayerId');
        }
      }
    } catch (e) {
      debugPrint('Error handling signaling: $e');
    }
  }

  void toggleMute() {
    if (localStream != null) {
      isMuted = !isMuted;
      localStream!.getAudioTracks().forEach((track) {
        track.enabled = !isMuted;
      });
      notifyListeners();
      debugPrint('Microphone ${isMuted ? 'muted' : 'unmuted'}');
    }
  }

  void dispose() {
    localStream?.dispose();
    peerConnections.forEach((_, peer) => peer.close());
    peerConnections.clear();
    _webSocketService.socket.off('voiceSignal');
    debugPrint('VoiceChatService disposed');
  }
}