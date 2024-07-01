import 'dart:async';
import 'dart:developer';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocket {
  // ------------------------- Members ------------------------- //
  late String url; // URL del servidor de Websockets
  WebSocketChannel? _channel; // Canal de Websockets para la comunicación

  // Controlador de transmisión para gestionar el estado de la conexión
  StreamController<bool> streamController = StreamController<bool>.broadcast();

  // ---------------------- Getter Setters --------------------- //
  String get getUrl {
    return url;
  }

  set setUrl(String url) {
    this.url = url;
  }

  Stream<dynamic> get stream {
    if (_channel != null) {
      // Devuelve el flujo de datos del canal si está disponible
      return _channel!.stream;
    } else {
      throw WebSocketChannelException("The connection was not established !");
    }
  }

  // --------------------- Constructor ---------------------- //
  WebSocket(
      this.url); // Constructor que recibe la URL del servidor de Websockets

  // ---------------------- Functions ----------------------- //

  // Conecta la aplicación actual al servidor de Websockets
  Future<bool> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      log("Conectando...");
      await _channel!.ready;
      log("Conexión establecida correctamente");
      return true;
    } catch (e) {
      log("Error al conectar: $e");
      return false;
    }
  }

  // Desconecta la aplicación actual del servidor de Websockets
  void disconnect() {
    if (_channel != null) {
      // Cierra el canal de manera ordenada
      _channel!.sink.close(status.normalClosure);
    }
  }
}
