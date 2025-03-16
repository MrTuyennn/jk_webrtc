<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# JK WebRTC

A Flutter WebRTC package that provides easy-to-use WebRTC functionality for your Flutter applications.

## Features

- Video/Audio calling
- Data channel support
- Screen sharing
- Custom WebRTC implementation
- Easy-to-use API

## Installation

To use this package, add `jk_webrtc` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  jk_webrtc:
    git:
      url: https://github.com/MrTuyennn/jk_webrtc.git
      ref: main
```

Then run:
```bash
flutter pub get
```

## Usage

### Basic Setup

```dart
import 'package:jk_webrtc/jk_webrtc.dart';

// Initialize signaling
final signaling = Signaling(
  selfId,     // Your user ID
  peerId,     // Peer's ID
  onlyDataChannel,  // true if you only need data channel
  localVideo, // true to enable local video
);

// Listen for state changes
signaling.onSignalingStateChange = (SignalingState state) {
  // Handle state changes
};

// Listen for call state changes
signaling.onCallStateChange = (Session session, CallState state) {
  // Handle call state changes
};

// Listen for local stream
signaling.onLocalStream = (MediaStream stream) {
  // Handle local stream
};
```

### Making a Call

```dart
// Start a call
await signaling.invite(peerId, {
  'audio': true,
  'video': true,
  'datachannel': true
});
```

### Handling Data Channel

```dart
// Listen for data channel messages
signaling.onDataChannelMessage = (Session session, RTCDataChannel dc, RTCDataChannelMessage data) {
  // Handle received messages
};

// Send message through data channel
session.dc?.send(RTCDataChannelMessage('Hello!'));
```

## Additional Configuration

### ICE Servers

You can configure ICE servers in your implementation:

```dart
final Map<String, dynamic> _iceServers = {
  'iceServers': [
    {'url': 'stun:your-stun-server:port'},
    {
      'url': 'turn:your-turn-server:port',
      'username': 'username',
      'credential': 'credential'
    },
  ]
};
```

## Example

Check the example directory for a complete example app.

## Requirements

- Flutter: >=1.17.0
- Dart SDK: ^3.5.2
- Dependencies:
  - flutter_webrtc (custom implementation)
  - shared_preferences: ^2.0.9
  - path_provider: ^2.0.7
  - event_bus: ^2.0.0

## Contributing

Feel free to contribute to this project.

1. Fork it
2. Create your feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
