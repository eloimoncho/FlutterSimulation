import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:frontend_flutter/MQTTClientManager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:mqtt_client/mqtt_client.dart';
import 'dart:io' show Platform;

import 'custom_drawer.dart';
import 'api_service.dart';
import 'navigation_origin.dart';
import 'photo_gallery.dart';
import 'video_gallery.dart';

// A map to hold the marker images
Map<String, ui.Image?> markerImage = {};

// TextPainter to draw text on images
TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

class MyMarker {
  Marker marker;
  int index;
  String imagePath;
  Color textColor;

  MyMarker({
    required this.marker,
    required this.index,
    required this.imagePath,
    required this.textColor,
  });
}

// Function to prepare marker image
Future<void> prepareMarkerImage(String path) async {
  // Load custom marker image
  final ByteData imageByteData = await rootBundle.load('assets/$path');
  final Uint8List imageUint8list = imageByteData.buffer.asUint8List();
  final img.Image originalImage = img.decodeImage(imageUint8list)!;

  // Determine the size based on the platform
  final int size = Platform.isAndroid || Platform.isIOS ? 128 : 64;

  // Resize the original image
  final img.Image resizedImage =
      img.copyResize(originalImage, width: size, height: size);

  // Convert the resized image back to Uint8List
  Uint8List resizedData = img.encodePng(resizedImage);

  // Create image from list of bytes
  final ui.Codec codec = await ui.instantiateImageCodec(resizedData);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();

  // Store the image in the markerImage map with its path as the key
  markerImage[path] = frameInfo.image;
}

// Function to create a marker bitmap
Future<BitmapDescriptor> createMarkerBitmap(
    String text, Color color, String imagePath) async {
  // Get the image from the map using imagePath
  ui.Image? selectedImage = markerImage[imagePath];

  // If the image is not found, log an error and return a default marker
  if (selectedImage == null) {
    debugPrint('No image found for path: $imagePath');
    return BitmapDescriptor.defaultMarker;
  }

  // Determine the text size based on the platform
  final double textSize = Platform.isAndroid || Platform.isIOS ? 50.0 : 25.0;

  // Create a PictureRecorder and Canvas to draw on
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);

  // Draw the image on the canvas
  canvas.drawImage(selectedImage, Offset.zero, Paint());

  Color borderColor = color == Colors.black ? Colors.white : Colors.black;
  // Draw the stroke (border)
  textPainter.text = TextSpan(
    text: text,
    style: TextStyle(
      fontSize: textSize,
      fontWeight: FontWeight.bold,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = borderColor,
    ),
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      (selectedImage.width - textPainter.width) / 2,
      (selectedImage.height - textPainter.height) / 2 -
          textPainter.height * 0.15,
    ),
  );

  // Draw the fill
  textPainter.text = TextSpan(
    text: text,
    style: TextStyle(
      fontSize: textSize,
      color: color,
      fontWeight: FontWeight.bold,
    ),
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      (selectedImage.width - textPainter.width) / 2,
      (selectedImage.height - textPainter.height) / 2 -
          textPainter.height * 0.15,
    ),
  );

  // Convert the PictureRecorder to an image
  final ui.Image markerAsImage = await pictureRecorder
      .endRecording()
      .toImage(selectedImage.width, selectedImage.height);

  // Convert the image to byte data and then to Uint8List
  final ByteData? byteData =
      await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List byteUint8list = byteData!.buffer.asUint8List();

  // Convert the Uint8List to a bitmap
  final bitmap = BitmapDescriptor.fromBytes(byteUint8list);

  return bitmap;
}


class MainScreen extends StatefulWidget {
  final Map? flightPlan;
  final Map? flight;
  final NavigationOrigin? origin;

  const MainScreen({Key? key, this.flightPlan, this.flight, this.origin})
      : super(key: key);
  
  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late GoogleMapController mapController;
  double droneLatitude = 0.0;
  double droneLongitude = 0.0;
  ApiService apiService = ApiService();

  // These variables hold the state of the map
  int _waypointCounter = 0;
  final Map<MarkerId, MyMarker> _markers = {};
  final List<LatLng> _polylineCoordinates = [];
  final Set<Polyline> _polylines = {};
  bool _isLoopClosed = false;
  bool _canTapMap = true;
  MQTTClientManager mqttClientManager = MQTTClientManager();

  BitmapDescriptor? homeIcon;
  BitmapDescriptor? waypointIcon;
  BitmapDescriptor? droneIcon;

  // The initial center position of the map
  final LatLng _center = const LatLng(41.276382, 1.988964);
  List<Map<String, dynamic>> newWaypoints = [];

  MarkerId? _selectedMarkerId;

  final String pubTopic = "+/mobileApp/#";

  @override
  void initState() {
    super.initState();
    setupMqttClient();

    // Load the icons at the start
    loadHomeIcon()
        .then((_) => prepareMarkerImage('waypoint_icon.png'))
        .then((_) => prepareMarkerImage('waypoint_icon_red.png'))
        .then((_) => prepareMarkerImage('waypoint_icon_green.png'))
        .then((_) => prepareMarkerImage('waypoint_icon_purple.png'))
        .then((_) => prepareMarkerImage('waypoint_icon_orange.png'))
        .then((_) => loadDroneIcon())
        .then((_) {
      if (widget.flightPlan != null) {
        loadFlightPlan(widget.flightPlan!);
      } else if (widget.flight != null) {
        loadFlightPlan(widget.flight!["FlightPlan"]);
      }
    });

    mqttClientManager.onConnected();
  }

  Future<void> loadHomeIcon() async {
    await prepareMarkerImage('home_icon.png');
    homeIcon = BitmapDescriptor.fromBytes((await markerImage['home_icon.png']!
            .toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List());
  }

  Future<void> loadDroneIcon() async {
    await prepareMarkerImage('drone_icon.png');
    droneIcon = BitmapDescriptor.fromBytes((await markerImage['drone_icon.png']!
            .toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List());
  }

  // Callback for when the map is created
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    // Programmatically set the tilt to 0 after the map has been created
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: _center,
      zoom: 19.5,
      tilt: 0.0,
    )));
  }

  // Callback for when the map is tapped
  Future<void> _handleTap(LatLng point) async {
    if (!_canTapMap) {
      return;
    }
    if (_isLoopClosed) {
      if (_selectedMarkerId != null) {
        MarkerId id = _selectedMarkerId!;
        MyMarker mymarker = _markers[id]!;
        int markerIndex = _polylineCoordinates
            .indexWhere((LatLng latlng) => latlng == mymarker.marker.position);

        // Create a new marker with the original color and update the marker icon
        Marker newMarker = Marker(
          markerId: id,
          position: point,
          icon: await createMarkerBitmap(
              id.value, mymarker.textColor, mymarker.imagePath),
          onTap: () => _handleMarkerTap(id),
          consumeTapEvents: true,
        );
        MyMarker myMarker = MyMarker(
          marker: newMarker,
          index: mymarker.index,
          imagePath: mymarker.imagePath,
          textColor: mymarker.textColor,
        );
        setState(() {
          _markers[newMarker.markerId] = myMarker;

          // Here we also update the polylineCoordinates by replacing the position of the moved marker
          _polylineCoordinates[markerIndex] = point;

          // Close the loop again if it was closed before
          if (_polylineCoordinates.first != _polylineCoordinates.last) {
            _polylineCoordinates.add(_polylineCoordinates.first);
          }

          _updatePolylines();

          // Deselect the marker
          _selectedMarkerId = null;
        });
        return; // Stop further execution of the _handleTap method after moving a marker
      }
    } else {
      double threshold = 0.00005;
      bool closeToStart = (_polylineCoordinates.isNotEmpty &&
          (point.latitude - _polylineCoordinates.first.latitude).abs() <
              threshold &&
          (point.longitude - _polylineCoordinates.first.longitude).abs() <
              threshold);
      if (closeToStart) {
        // Close the loop
        _closeLoop();
      } else {
        BitmapDescriptor markerBitmap;

        if (_waypointCounter == 0) {
          markerBitmap = homeIcon!;
        } else {
          markerBitmap = await createMarkerBitmap(
            (_waypointCounter).toString(),
            Colors.black,
            'waypoint_icon.png',
          );
        }
        setState(() {
          MarkerId markerId = MarkerId(_waypointCounter.toString());
          Marker m = Marker(
            markerId: markerId,
            position: point,
            icon: markerBitmap,
            onTap: () => _handleMarkerTap(markerId),
          );
          MyMarker myMarker = MyMarker(
            marker: m,
            index: _waypointCounter,
            imagePath: 'waypoint_icon.png',
            textColor: Colors.black,
          );
          _markers[m.markerId] = myMarker;
          _waypointCounter++;

          _polylineCoordinates.add(point);
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              visible: true,
              points: _polylineCoordinates,
              color: Colors.blue,
              width: 6,
            ),
          );
        });
      }
    }
  }

  // Function to close the loop
  _closeLoop() {
    setState(() {
      _isLoopClosed = true;
      _polylineCoordinates.add(_polylineCoordinates.first);
      _updatePolylines();
    });
  }

  // Callback for when a marker is tapped
  void _handleMarkerTap(MarkerId markerId) async {
    if (!_markers.containsKey(markerId)) {
      debugPrint('Marker with id: $markerId not found');
      return;
    }
    if (!_isLoopClosed || _markers[markerId]?.index == 0 || !_canTapMap) {
      // Don't allow selecting waypoints before the loop is closed or the home marker or if the dialog is open
      return;
    }

    // Obtain the geographical position of the marker
    LatLng markerPosition = _markers[markerId]!.marker.position;

    // Convert the geographical coordinates to screen coordinates
    ScreenCoordinate screenCoordinate =
        await mapController.getScreenCoordinate(markerPosition);

    double dx = screenCoordinate.x.toDouble();
    double dy = screenCoordinate.y.toDouble();

    _canTapMap = false;

    _showOptionsDialog(context, markerId, Offset(dx, dy));
  }

  void _showOptionsDialog(
      BuildContext context, MarkerId markerId, Offset offset) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext buildContext, Animation animation,
          Animation secondaryAnimation) {
        return WillPopScope(
          onWillPop: () async {
            _canTapMap = true;
            return true;
          },
          child: SafeArea(
            child: Builder(builder: (BuildContext context) {
              if (kIsWeb) {
                return Stack(
                  children: [
                    Positioned(
                      left: offset.dx,
                      top: offset.dy,
                      child: _buildAlertDialog(context, markerId),
                    ),
                  ],
                );
              } else {
                return Center(
                  child: _buildAlertDialog(context, markerId),
                );
              }
            }),
          ),
        );
      },
    );
  }

  Widget _buildAlertDialog(BuildContext context, MarkerId markerId) {
    return AlertDialog(
      title: const Text('Marker Options'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            GestureDetector(
              child: const Text("Move Marker"),
              onTap: () {
                Navigator.of(context).pop();
                _startMovingMarker(markerId);
                Future.delayed(const Duration(milliseconds: 500), () {
                  _canTapMap = true;
                });
              },
            ),
            const Padding(padding: EdgeInsets.all(8.0)),
            GestureDetector(
              child: const Text("Change Color"),
              onTap: () {
                Navigator.of(context).pop();
                _changeMarkerColor(markerId);
                Future.delayed(const Duration(milliseconds: 500), () {
                  _canTapMap = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Function to change the marker color
  Future<void> _changeMarkerColor(MarkerId markerId) async {
    MyMarker? myMarker = _markers[markerId];

    if (myMarker == null) {
      debugPrint('No marker found for id: $markerId');
      return;
    }

    // Change the marker color and image
    String newImagePath = myMarker.imagePath == 'waypoint_icon_green.png'
        ? 'waypoint_icon.png'
        : 'waypoint_icon_green.png';
    Color newTextColor =
        myMarker.textColor == Colors.green ? Colors.black : Colors.green;

    Marker newMarker = Marker(
      markerId: markerId,
      position: myMarker.marker.position,
      onTap: () => _handleMarkerTap(markerId),

      icon: await createMarkerBitmap(
          '${myMarker.index}', newTextColor, newImagePath),
      consumeTapEvents: true, // enable the long press event to be triggered
    );

    setState(() {
      myMarker.marker = newMarker;
      myMarker.imagePath = newImagePath;
      myMarker.textColor = newTextColor;
    });
  }

  // Function to update polylines
  void _updatePolylines() {
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          visible: true,
          points: _polylineCoordinates,
          color: Colors.blue,
          width: 8,
        ),
      );
    });
  }

  // Function to start moving a marker
  void _startMovingMarker(MarkerId markerId) async {
    MyMarker myMarker = _markers[markerId]!;

    if (_selectedMarkerId != null && _selectedMarkerId != markerId) {
      // If a different marker was previously selected, then deselect it
      MyMarker previouslySelectedMarker = _markers[_selectedMarkerId!]!;
      Marker markerToDeselect = previouslySelectedMarker.marker;
      Marker newMarker = Marker(
        markerId: MarkerId('${previouslySelectedMarker.index}'),
        position: markerToDeselect.position,
        onTap: () => _handleMarkerTap(markerToDeselect.markerId),
        icon: await createMarkerBitmap(
            '${previouslySelectedMarker.index}',
            previouslySelectedMarker.textColor,
            previouslySelectedMarker.imagePath),
        consumeTapEvents: true,
      );
      setState(() {
        previouslySelectedMarker.marker = newMarker;
      });
    }

    // Select the tapped marker
    Marker selectedMarker = myMarker.marker;
    Marker newMarker = Marker(
      markerId: selectedMarker.markerId,
      position: selectedMarker.position,
      onTap: () => _handleMarkerTap(selectedMarker.markerId),
      icon: await createMarkerBitmap(
          '${myMarker.index}', Colors.red, 'waypoint_icon_red.png'),
      consumeTapEvents: true,
    );
    setState(() {
      myMarker.marker = newMarker;
      _selectedMarkerId = newMarker.markerId;
    });
  }

  void loadFlightPlan(Map flightplan) async {
    _canTapMap = false;
    bool movingVideoBool = false;
    List<dynamic> flightWaypoints = flightplan["FlightWaypoints"];
    List<dynamic> picsWaypoints = flightplan['PicsWaypoints'];
    List<dynamic> vidWaypoints = flightplan['VidWaypoints'];
    List<LatLng> currentPolylineCoordinates = [];
    Color lastColor = Colors.blue;

    for (var waypoint in flightWaypoints) {
      var newWaypoint = Map<String, dynamic>.from(waypoint);

      // Check if waypoint is in picsWaypoints
      bool hasPic = picsWaypoints.any((picWaypoint) =>
          picWaypoint['lat'] == waypoint['lat'] &&
          picWaypoint['lon'] == waypoint['lon']);

      // Check if waypoint is in vidWaypoints for static videos
      var staticVideo = vidWaypoints.firstWhere(
          (vidWaypoint) =>
              vidWaypoint['mode'] == "static" &&
              vidWaypoint['lat'] == waypoint['lat'] &&
              vidWaypoint['lon'] == waypoint['lon'],
          orElse: () => null);

      // Check if waypoint is in vidWaypoints for moving videos
      var movingVideo = vidWaypoints.firstWhere(
          (vidWaypoint) =>
              vidWaypoint['mode'] == "moving" &&
              (vidWaypoint['latStart'] == waypoint['lat'] &&
                      vidWaypoint['lonStart'] == waypoint['lon'] ||
                  vidWaypoint['latEnd'] == waypoint['lat'] &&
                      vidWaypoint['lonEnd'] == waypoint['lon']),
          orElse: () => null);

      newWaypoint['takePic'] = hasPic;
      newWaypoint['staticVideo'] = staticVideo != null;
      newWaypoint['movingVideo'] = movingVideo != null;

      newWaypoints.add(newWaypoint);

      LatLng point = LatLng(waypoint['lat'], waypoint['lon']);
      if (newWaypoint['movingVideo']) movingVideoBool = !movingVideoBool;

      BitmapDescriptor markerBitmap;
      if (_waypointCounter == 0) {
        markerBitmap = homeIcon!;
      } else if (newWaypoint['staticVideo'] && newWaypoint['takePic']) {
        markerBitmap = await createMarkerBitmap(
          (_waypointCounter).toString(),
          Colors.purple,
          'waypoint_icon_purple.png',
        );
      } else if (newWaypoint['staticVideo']) {
        markerBitmap = await createMarkerBitmap(
          (_waypointCounter).toString(),
          Colors.green,
          'waypoint_icon_green.png',
        );
      } else if (newWaypoint['takePic']) {
        markerBitmap = await createMarkerBitmap(
          (_waypointCounter).toString(),
          Colors.orange,
          'waypoint_icon_orange.png',
        );
      } else if (newWaypoint['movingVideo']) {
        markerBitmap = await createMarkerBitmap(
          (_waypointCounter).toString(),
          Colors.red,
          'waypoint_icon_red.png',
        );
      } else {
        markerBitmap = await createMarkerBitmap(
          (_waypointCounter).toString(),
          Colors.black,
          'waypoint_icon.png',
        );
      }

      setState(() {
        MarkerId markerId = MarkerId(_waypointCounter.toString());
        Marker m = Marker(
          markerId: markerId,
          position: point,
          icon: markerBitmap,
          onTap: () => _handleMarkerTap(markerId),
        );
        MyMarker myMarker = MyMarker(
          marker: m,
          index: _waypointCounter,
          imagePath: 'waypoint_icon.png',
          textColor: Colors.black,
        );
        _markers[m.markerId] = myMarker;
        _waypointCounter++;

        _polylineCoordinates.add(point);
        currentPolylineCoordinates.add(point);

        // When we have at least two points, we can create a polyline
        if (currentPolylineCoordinates.length >= 2) {
          Color currentColor = movingVideoBool ? Colors.green : Colors.blue;
          // If the color has changed or this is the last waypoint, add the polyline
          if (currentColor != lastColor || waypoint == flightWaypoints.last) {
            _polylines.add(
              Polyline(
                polylineId: PolylineId(_polylineCoordinates.length.toString()),
                visible: true,
                points: currentPolylineCoordinates, // copy the list
                color: lastColor,
                width: 6,
              ),
            );
            // Start a new polyline
            currentPolylineCoordinates = [point];
            lastColor = currentColor;
          }
        } else {
          lastColor = movingVideoBool ? Colors.green : Colors.blue;
        }
      });
    }

    // If the last waypoint doesn't close the loop, you can close it manually.
    if (_polylineCoordinates.first != _polylineCoordinates.last) {
      _polylineCoordinates.add(_polylineCoordinates.first);
      _polylines.add(
        Polyline(
          polylineId: PolylineId(_polylineCoordinates.length.toString()),
          visible: true,
          points: _polylineCoordinates
              .sublist(_polylineCoordinates.length - 2), // last two points
          color: movingVideoBool ? Colors.green : Colors.blue,
          width: 6,
        ),
      );
    }
    _isLoopClosed = true;
  }

  void sendFlightPlan(String flightPlanTitle) async {
    Map<String, dynamic> data = {
      "Title": flightPlanTitle,
      "waypoints": newWaypoints
    };
    mqttClientManager.publishMessage(
        "mobileApp/autopilotService/connect",
        json.encode(data));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connecting to the drone'),
        duration: Duration(seconds: 5),
      ),
    );
    mqttClientManager.publishMessage(
        "mobileApp/autopilotService/executeFlightPlanMobileApp",
        json.encode(data));
  }

  void showPhotoGallery(Map flight) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGallery(widget.flight!),
      ),
    );
  }

  void showVideoGallery(Map flight) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoGallery(widget.flight!),
      ),
    );
  }

  Future<void> setupMqttClient() async {
    await mqttClientManager.connect();
    mqttClientManager.subscribe(pubTopic);
    setupUpdatesListener();
  }

  void setupUpdatesListener() {
    mqttClientManager
        .getMessagesStream()!
        .listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MQTTClient::Message received on topic: <${c[0].topic}> is $pt\n');
      if (c[0].topic == "autopilotService/mobileApp/flightEnded") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flight has ended correctly'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      if (c[0].topic == "autopilotService/mobileApp/connectedAutopilot") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drone connected correctly. Starting flight'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      if (c[0].topic == "autopilotService/mobileApp/telemetryInfo") {
        print('telemetry info received');
        //Map telemetryInfo = json.decode(pt);
        // Extraer la latitud y longitud del dron de la información de telemetría
        final telemetryInfo = json.decode(pt);
        final droneLatitude = telemetryInfo['lat'];
        final droneLongitude = telemetryInfo['lon'];
        updateDronePosition(LatLng(droneLatitude, droneLongitude));;
      }
    });
  }

  void updateDronePosition(LatLng newPosition) {
    print('updateDronePosition EXECUTE');
    
    setState(() {
      // Agregar el nuevo marcador del dron
      _markers[MarkerId('drone')] = MyMarker(
        marker: Marker(
          markerId: MarkerId('drone'),
          position: newPosition,
          icon: droneIcon!, // Usar el icono del dron
          anchor: Offset(0.25, 0.65), // Centrar el marcador en su posición
        ),
        index: 0, // Ajustar el índice según sea necesario
        imagePath: 'assets/drone_icon.png', // Ruta de la imagen del dron
        textColor: Colors.black, // Color del texto
      );
    });
  }
  // The build method for the widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Planner'),
      ),
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.satellite,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 19.5,
            ),
            onTap: _handleTap,
            markers: _markers.values.map((e) => e.marker).toSet(),
            polylines: _polylines,
          ),
          if (widget.origin == NavigationOrigin.selectFlights)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  onPressed: () {
                    sendFlightPlan(widget.flightPlan!["Title"]);
                  },
                  child: const Text('Execute Flight Plan'),
                ),
              ),
            ),
          if (widget.origin == NavigationOrigin.pastFlights)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () {
                        showPhotoGallery(widget.flight!);
                      },
                      child: const Text('Photo Gallery'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        showVideoGallery(widget.flight!);
                      },
                      child: const Text('Video Gallery'),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 5,
            bottom: 5,
            child: Container(
              width: 100.0,
              height: 30.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: PopupMenuButton<int>(
                icon: const Icon(Icons.arrow_upward, color: Colors.black),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.red),
                        Text(' - Pictures'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.green),
                        Text(' - Videos'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.purple),
                        Text(' - Both'),
                      ],
                    ),
                  ),
                ],
                elevation: 8.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
