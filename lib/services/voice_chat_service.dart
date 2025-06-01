import 'dart:convert';
import 'package:crypto/crypto.dart';
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
  late final Map<String, dynamic> _iceServers;
  final Map<String, webrtc.RTCVideoRenderer> remoteRenderers = {};

  // Coturn server configuration
  static const String _coturnIp = '13.127.13.211'; // Your EC2 public IP
  static const String _turnSecret = 'begger5gr7yu5kusd5'; // From turnserver.conf (e.g., mysecurekey123)

  VoiceChatService(this._webSocketService, this.gameId, this.playerId) {
    _initializeIceServers();
    _initialize();
  }

  // Generate time-limited TURN credentials
  Map<String, String> _generateTurnCredentials(String username, String secret, {int ttl = 86400}) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + ttl;
    final turnUsername = '$timestamp:$username';
    final key = utf8.encode(secret);
    final input = utf8.encode(turnUsername);
    final hmacSha1 = Hmac(sha1, key);
    final digest = hmacSha1.convert(input);
    final credential = base64.encode(digest.bytes);
    return {'username': turnUsername, 'credential': credential};
  }

  // Initialize ICE servers with Coturn configuration
  void _initializeIceServers() {
    final credentials = _generateTurnCredentials(playerId, _turnSecret);
    _iceServers = {
      'iceServers': [
        {'urls': 'stun:$_coturnIp:3478'},
        {
          'urls': [
            'turn:$_coturnIp:3478?transport=udp',
            'turn:$_coturnIp:3478?transport=tcp',
          ],
          'username': credentials['username'],
          'credential': credentials['credential'],
        },
        {'urls': 'stun:stun.l.google.com:19302'}, // Fallback STUN server
      ]
    };
  }

  Future<void> _initialize() async {
    try {
      localStream = await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true, // Enable echo cancellation
          'noiseSuppression': true, // Enable noise suppression
          'autoGainControl': true, // Enable automatic gain control
          'channelCount': 1, // Mono audio for better processing
        },
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

      // Add onTrack event
      peer.onTrack = (webrtc.RTCTrackEvent event) async {
        debugPrint('Received remote stream from $targetConnectionId');
        if (event.streams.isNotEmpty) {
          // Attach remote stream to a renderer (Web needs this for audio output)
          await _attachRemoteStream(targetConnectionId, event.streams.first);
        }
        notifyListeners();
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
      rethrow;
    }
  }
  Future<void> _attachRemoteStream(String connectionId, webrtc.MediaStream remoteStream) async {
    if (!remoteRenderers.containsKey(connectionId)) {
      final renderer = webrtc.RTCVideoRenderer();
      await renderer.initialize();
      remoteRenderers[connectionId] = renderer;
    }
    remoteRenderers[connectionId]!.srcObject = remoteStream;
    // No need to attach to UI for audio, but renderer must stay alive!
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

    if (type != 'newVoiceParticipant' && toConnectionId == null) {
      debugPrint('Invalid signaling data (missing toConnectionId): $data');
      return;
    }

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


    remoteRenderers.forEach((_, renderer) {
      renderer.srcObject = null;
      renderer.dispose();
    });
    remoteRenderers.clear();

    _webSocketService.socket.off('voiceSignal');
    debugPrint('VoiceChatService disposed');
  }
}