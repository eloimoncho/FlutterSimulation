import 'package:flutter/material.dart';
import 'package:frontend_flutter/MQTTClientManager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';

class ApiService {
  static final ApiService _singleton = ApiService._internal();
  MQTTClientManager mqttClientManager = MQTTClientManager();
  final String pubTopic = "+/mobileApp/#";
  
  // Variable para almacenar los planes de vuelo recibidos por MQTT
  List<dynamic> _receivedFlightPlans = [];
  // Variable para almacenar los vuelos pasados recibidos por MQTT
  List<dynamic> _receivedPastFlights = [];
  factory ApiService() {
    return _singleton;
  }

  ApiService._internal() {
    // Realizar la conexión MQTT al crear una instancia de ApiService
    mqttClientManager.connect();
    setupUpdatesListener();
  }

  bool isConnected = false;
  var ipAddrGround = 'localhost:8105'; //localhost of emulator
  var ipAddrAir = 'localhost:9000';
  //var ipAddrGround = '147.83.249.79:8105'; //localhost of emulator
  //var ipAddrAir = '192.168.208.6:9000';

  // This next 3 functions are used to send the flight plan to RESTAPI which then in turn send it to the external broker, and the autopilot service
  // Its not the optimal way of doing it since it should be sent to the external broker through MQTT directly but i couldnt get it to work
  // This should be changed in the future you can try to follow this example https://github.com/shamblett/mqtt_client/blob/master/example/mqtt_server_client_websocket.dart
  Future<void> disconnectBroker() async {
    var url = Uri.parse('http://$ipAddrGround/disconnect');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      debugPrint('Successfully disconnected from the broker.');
      isConnected = false;
    } else {
      debugPrint(
          'Failed to disconnect from the broker: ${response.statusCode}: ${response.body}}');
    }
  }
  
  void handleMqttMessage(String topic, String message) {
    
    List<String> topicParts = topic.split('/');
    if (topicParts.length >= 3) {
      String command = topicParts[2];
    switch (command) {
      case "get_all_flightPlans":
        _receivedFlightPlans = jsonDecode(message);
        print(_receivedFlightPlans);
        //mostrar receivedFlight a select_flight
        break;
      case "get_all_flights":
        _receivedPastFlights = jsonDecode(message);
        print(_receivedFlightPlans);
        break;
      

      default:
        // topic no esperado
        print("Tema (topic) no reconocido: $topic");
        break;
      }
    }
  }
  void setupUpdatesListener() {
    mqttClientManager
        .getMessagesStream()!
        .listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MQTTClient::Message received on topic: <${c[0].topic}> is $pt\n');

      handleMqttMessage(c[0].topic, pt);
    });
  }

  /*Future<List<dynamic>> fetchFlightPlans() async {
    // Voy a los planes de vuelos que ya están cargados en la bbdd de aire
    final response =
        await http.get(Uri.parse('http://$ipAddrAir/get_all_flightPlans'));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['Waypoints'];
    } else {
      throw Exception('Failed to load flight plans');
    }
  }*/
  Future<List<dynamic>> fetchFlightPlans() async {
    // Esperar a que se reciban los datos por MQTT
    await mqttClientManager.connect();
    mqttClientManager.publishMessage(
        "mobileApp/airDataService/get_all_flightPlans", "NoPayload");

    // Devolver los planes de vuelo recibidos
    return _receivedFlightPlans;
  }

  /*Future<List<dynamic>> fetchPastFlights() async {
    final response =
        await http.get(Uri.parse('http://$ipAddrGround/get_all_flights'));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to load flight plans');
    }
  }*/

  Future<List<dynamic>> fetchPastFlights() async {
    // Esperar a que se reciban los datos por MQTT
    await mqttClientManager.connect();
    mqttClientManager.publishMessage(
        "mobileApp/groundDataService/get_all_flights", "NoPayload");
    
    // Devolver los planes de vuelo recibidos
    return _receivedPastFlights;
  }

  String getImageUrl(String imagePath) {
    mqttClientManager.publishMessage(
        "mobileApp/groundDataService/get_pictures", imagePath);
    return 'http://$ipAddrGround/media/pictures/$imagePath';
  }

  String getVideoUrl(String videoPath) {
    return 'http://$ipAddrGround/media/videos/$videoPath';
  }

  String getThumbnailUrl(String videoPath) {
    return 'http://$ipAddrGround/thumbnail/$videoPath';
  }

  
}