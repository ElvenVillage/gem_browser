import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

const int GEMINI_DEFAULT_PORT = 1965;
const int TIMEOUT_DURATION_SECONDS = 500;

final encoderProvider = Provider((_) => Utf8Encoder());
final decoderProvider = Provider((_) => Utf8Decoder());

final geminiProvider = FutureProvider.family<String, Uri>((ref, url) async {
  final encoder = ref.watch(encoderProvider);
  final decoder = ref.watch(decoderProvider);

  final port = url.hasPort ? url.port : GEMINI_DEFAULT_PORT;
  final request = encoder.convert(url.toString() + '\r\n');

  final socket = await RawSecureSocket.connect(url.host, port,
      onBadCertificate: (cert) => true,
      timeout: Duration(seconds: TIMEOUT_DURATION_SECONDS));

  var wasTimeoutExceeded = false;
  final socketDataStream = socket
      .timeout(Duration(seconds: TIMEOUT_DURATION_SECONDS), onTimeout: (sink) {
    sink.close();
    socket.close();
    wasTimeoutExceeded = true;
  });

  var response = '';

  await for (var event in socketDataStream) {
    switch (event) {
      case RawSocketEvent.write:
        socket.write(request);
        break;
      case RawSocketEvent.read:
        response += decoder.convert(socket.read()?.toList() ?? []);
        break;
      case RawSocketEvent.readClosed:
      case RawSocketEvent.closed:
        socket.close();
        return response;
    }
  }
  socket.close();
  if (wasTimeoutExceeded)
    throw TimeoutException('Could not fetch data');
  else
    return response;
});
