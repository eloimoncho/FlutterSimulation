// Importaciones necesarias para el funcionamiento del código
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frontend_flutter/MQTTClientManager.dart';
import 'package:frontend_flutter/custom_drawer.dart';

// Importación de la clase de servicios de Websockets
import '../../services/websockets.dart';

class DroneStreamPage extends StatefulWidget {
  const DroneStreamPage({Key? key}) : super(key: key);

  @override
  State<DroneStreamPage> createState() => _DroneStreamPageState();
}

class _DroneStreamPageState extends State<DroneStreamPage> {  
  // Instancia de la clase WebSocket para manejar la conexión por Websockets
  final WebSocket _socket = WebSocket("ws://192.168.1.63:42888");
  MQTTClientManager mqttClientManager = MQTTClientManager();
  bool _isConnected = false;
  final String pubTopic = "+/mobileApp/#";

  // Método para conectar al servidor a través de Websockets
  void connect(BuildContext context) async {
    await mqttClientManager.connect();
    mqttClientManager.publishMessage(
        "mobileApp/cameraService/dronestream_websockets", "NoPayload");
    _isConnected = await _socket.connect();
    log("Is connected? $_isConnected");

    // Actualizar el estado del widget para reflejar la conexión
    setState(() {
      //_isConnected = _isConnected;
    });
    
  }

  // Método para desconectar del servidor Websockets
  void disconnect() {
    _socket.disconnect();

    // Actualizar el estado del widget para reflejar la desconexión
    setState(() {
      _isConnected = false;
    });
  }



  // Construcción de la interfaz de usuario
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WebSocket DroneStream"),
      ),
      drawer: const CustomDrawer(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Visibility(
                          visible: !_isConnected,
                          child: ElevatedButton(
                            onPressed: () => connect(context),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black, 
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text("Conectar"),
                            
                          ),
                        ),
                        //const SizedBox(width: 10),
                        Visibility(
                          visible: _isConnected,
                          child: ElevatedButton(
                            onPressed: disconnect,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.orange, 
                              backgroundColor: Colors.white,
                            ),
                            child: const Text("Desconectar"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 50.0,
                  ),
                  // StreamBuilder para recibir y mostrar el video del dron
                  _isConnected
                      ? StreamBuilder(
                          stream: _socket.stream,
                          builder: (context, snapshot) {
                            // Si no hay datos, mostrar un indicador de carga
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator(
                                color: Colors.orange,
                              );
                            }

                            // Si la conexión está terminada, mostrar un mensaje
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return const Center(
                                child: Text("Conexión terminada"),
                              );
                            }

                            // Mostrar la imagen recibida a través de Websockets
                            return Image.memory(
                              Uint8List.fromList(
                                base64Decode(
                                  (snapshot.data.toString()),
                                ),
                              ),
                              gaplessPlayback: true,
                              excludeFromSemantics: true,
                            );
                          },
                        )
                      : const Text("Iniciar conexión")
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
