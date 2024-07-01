# Flutter Front End

## Table of Contents

1. [Introduction](#introduction)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Getting Started](#getting-started)
5. [Set Up](#set-up)
6. [Usage](#usage)
7. [Demo Flutter](#demo-flutter)

## Introduction

The Flutter Front End is a new front end made with Flutter, which sets out to create an intuitive mobile ui to both create new flights and view previous ones. It communicates with the RestApi backend to obtain all the needed information from the database.

## Requirements

Before starting with the installation, make sure you have the following software installed on your system:

- Flutter
- VsCode (or any preferred IDE)
- Android Studio (for the mobile emulator)


The following modules are required for full functionality, or at least having connection to them:

- Air APIREST [![DroneEngineeringEcosystem Badge](https://img.shields.io/badge/DEE-AirAPIREST-brightgreen.svg)](https://github.com/dronsEETAC/AirAPIREST)
- Ground APIREST [![DroneEngineeringEcosystem Badge](https://img.shields.io/badge/DEE-GroundAPIREST-brightgreen.svg)](https://github.com/dronsEETAC/GroundAPIREST)
- AutopilotService [![DroneEngineeringEcosystem Badge](https://img.shields.io/badge/DEE-AutopilotService-brightgreen.svg)](https://github.com/dronsEETAC/autopilotService)

## Installation

For all the installation you can watch the first 20 minutes of this video [Flutter Tutorial For Beginners](https://www.youtube.com/watch?v=CD1Y2DmL5JM) if you're completely new to Flutter I recommend you watch it all and try to follow along.

## Getting Started

These are some useful resources for flutter development:
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Set Up

You will first need to make sure you got all the dependencies by running
```
flutter pub get
```
Then you will need to make sure you have the emulator opened and running (in this case were using vscode)    
<img src="https://github.com/dronsEETAC/FlutterApp/assets/100842082/929d94c7-34a5-4d96-83c1-e4b17a8e45f4" width="200" height="400">

Finally, you can run the following command to build the project
```
flutter run
```

## Usage 

When the project is running you should be met with the main map. in this window, you can click on the map to add waypoints and then click again around the initial waypoint to close the loop (it might take a few tries).    
<img src="https://github.com/dronsEETAC/FlutterApp/assets/100842082/42317fc9-dfd0-4c42-9e15-9e3ac6755bb0" width="200" height="400">

When the loop is closed you can click on a waypoint to edit it:    
<img src="https://github.com/dronsEETAC/FlutterApp/assets/100842082/96225472-c1e8-4a8c-bbf3-1914ef44cb61" width="200" height="400">

The current functionality of this standalone is quite limited and has a lot of room for improvement.

__For the other functionalities you will need to have the required modules, both APIREST modules and onboard services, running.__

The select flight screen allows you to select flights plans from the database and run them as long as you're connected

<img src="https://github.com/dronsEETAC/FlutterApp/assets/100842082/259b901f-f41e-4f82-87ec-71c3b21a6796" width="200" height="400">

When a flight plan is selected, it is shown inside the map, allowing to see the points were images, dinamic videos or static ones iwll be taken


<img src="https://github.com/dronsEETAC/FlutterApp/assets/100842082/e039d10f-1d3c-4d5b-aa43-b4a726a367ec" width="200" height="400">

The past flights screen allows you to select past flights and see the path as well as a video and image gallery 

<img src="https://github.com/dronsEETAC/FlutterApp/assets/100842082/2c3935be-4aed-4d17-b32f-9251cacbeb5a" width="200" height="400">

For example, in the following picture two images can be seen, as it was expected to take one on waypoint number 1, and another in number 5    
<img src="https://github.com/dronsEETAC/FlutterApp/assets/100842082/051f373c-45be-4e66-ba7b-b8a9894d45ca" width="200" height="400">

## Demo Flutter

In order to be able to see a real simulation of an execution of a planned flight, the following demo performs the complete process of creating a flight plan:
 [![DroneEngineeringEcosystem Badge](https://img.shields.io/badge/DEE-Demo_FlutterApp-pink.svg)](https://www.youtube.com/watch?v=AMLKRCThTbs&t=150s&ab_channel=DronsEETAC)

In the video:
1. Using Dashboard, a flight plan is created using functionality "Fix waypoints by hand".
2. Once the flight plan is saved in ground backend, it is sent to air backend using "Save in Drone" button.
3. Using the Flutter application, all the flight plans collected in air backend can be seen, and one of them is selected for its execution.
4. With the help of Mission Planner, the flight is followed over all its waypoints, taking the required images or videos when asked.
5. When the flight has landed, and using functionality "Past flights" in Flutter application, data collected, and already saved in ground backend, can be seen and analyzed.


