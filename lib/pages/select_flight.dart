import 'dart:convert';

import 'package:flutter/material.dart';
import '../custom_drawer.dart';
import 'main_screen.dart';
import '../services/MQTTClientManager.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../navigation_origin.dart';
import 'dart:async';

class SelectFlight extends StatefulWidget {
  const SelectFlight({Key? key}) : super(key: key);

  @override
  SelectFlightState createState() => SelectFlightState();
}

class SelectFlightState extends State<SelectFlight> {
  Future<List<dynamic>>? _flightPlans;
  MQTTClientManager mqttClientManager = MQTTClientManager();
  final String pubTopic = "+/mobileApp/#";

  @override
  void initState() {
    super.initState();
    getFlightPlans();
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
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MQTTClient::Message received on topic: <${c[0].topic}> is $pt\n');
      if (c[0].topic == "airDataService/mobileApp/get_all_flightPlans") {
        String jsonString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        Map<String, dynamic> jsonData = jsonDecode(jsonString);
        _flightPlans = Future.value(jsonData['Waypoints']);
        setState(() {}); // Actualizar la UI cuando se reciban los datos
      }
    });
  }

  void getFlightPlans() async {
    await mqttClientManager.connect();
    mqttClientManager.publishMessage(
        "mobileApp/airDataService/get_all_flightPlans", "NoPayload");
    print("getFlightPlans");
    mqttClientManager.subscribe(pubTopic);
    setupUpdatesListener();
  }

  void changeScreen(Map flightPlan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          flightPlan: flightPlan,
          origin: NavigationOrigin.selectFlights,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Flight Page'),
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        child: FutureBuilder<List<dynamic>>(
          future: _flightPlans,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Column(
                children: [
                  DataTable(
                    showCheckboxColumn: false,
                    columns: const <DataColumn>[
                      DataColumn(
                        label: Text('Date'),
                      ),
                      DataColumn(label: Text('Title')),
                      DataColumn(
                        label: Text('Waypoints'),
                      ),
                    ],
                    rows: snapshot.data!.map((flightPlan) {
                      var date = DateTime.fromMillisecondsSinceEpoch(
                          flightPlan['DateAdded']['\$date']);
                      return DataRow(
                        selected: false,
                        cells: <DataCell>[
                          DataCell(
                              Text('${date.day}-${date.month}-${date.year}')),
                          DataCell(Text(flightPlan['Title'].toString())),
                          DataCell(Text(flightPlan['NumWaypoints'].toString())),
                        ],
                        // When a row is clicked, send its flight plan
                        onSelectChanged: (_) {
                          changeScreen(flightPlan);
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    mqttClientManager.disconnect();
    super.dispose();
  }
}
