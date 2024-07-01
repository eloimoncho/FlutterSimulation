import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend_flutter/MQTTClientManager.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'custom_drawer.dart';
import 'main_screen.dart';
import 'navigation_origin.dart';
import 'dart:async';

class PastFlights extends StatefulWidget {
  const PastFlights({Key? key}) : super(key: key);

  @override
  PastFlightsState createState() => PastFlightsState();
}

class PastFlightsState extends State<PastFlights> {
  Future<List<dynamic>>? _pastFlights;
  MQTTClientManager mqttClientManager = MQTTClientManager();
  final String pubTopic = "+/mobileApp/#";

  @override
  void initState() {
    super.initState();
    getPastFlights();
  }

  Future<void> setupMqttClient() async {
    print("setupMqttClient");
    await mqttClientManager.connect();
    mqttClientManager.subscribe(pubTopic);
    setupUpdatesListener();
  }

  void setupUpdatesListener() {
    print("setupUpdatesListener");
    mqttClientManager
        .getMessagesStream()!
        .listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MQTTClient::Message received on topic: <${c[0].topic}> is $pt\n');
      if (c[0].topic == "groundDataService/mobileApp/get_all_flights") {
        String jsonString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        dynamic jsonData = jsonDecode(jsonString);
        _pastFlights = Future.value(jsonData);
        print('PAST FLIGHTS:' + _pastFlights.toString());
        setState(() {}); // Actualizar la UI cuando se reciban los datos
      }
    });
  }

  void getPastFlights() async {
    await mqttClientManager.connect();
    mqttClientManager.publishMessage(
        "mobileApp/groundDataService/get_all_flights", "NoPayload");
    print("getPastFlights");
    mqttClientManager.subscribe(pubTopic);
    setupUpdatesListener();
  }

  void changeScreen(Map flight) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          flight: flight,
          origin: NavigationOrigin.pastFlights,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Flights'),
      ),
      drawer: const CustomDrawer(),
      body: FutureBuilder<List<dynamic>>(
        future: _pastFlights,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            //print("snapshot data" + snapshot.data);
            return SingleChildScrollView(
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Pics')),
                  DataColumn(label: Text('Vids')),
                  DataColumn(label: Text('Waypoints')),
                ],
                rows: List<DataRow>.generate(
                  snapshot.data.length,
                  (int index) {
                    var flight = snapshot.data[index];
                    var date = DateTime.fromMillisecondsSinceEpoch(
                        flight["Date"]["\$date"]);
                    String dateString =
                        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
                    return DataRow(
                      cells: [
                        DataCell(Text(dateString)),
                        DataCell(Text(flight["NumPics"].toString())),
                        DataCell(Text(flight["NumVids"].toString())),
                        DataCell(Text(
                            flight["FlightPlan"]["NumWaypoints"].toString())),
                      ],
                      onSelectChanged: (_) => changeScreen(flight),
                    );
                  },
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Text("${snapshot.error}");
          }else {
            print("No hay datos disponibles.");
          }

          return const CircularProgressIndicator();
        },
      ),
    );
  }
}
