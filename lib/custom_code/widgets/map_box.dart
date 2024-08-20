// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

class MapBox extends StatefulWidget {
  const MapBox({
    Key? key,
    this.width,
    this.height,
    this.accessToken,
    this.taskId,
  }) : super(key: key);

  final double? width;
  final double? height;
  final String? accessToken;
  final String? taskId;

  @override
  State<MapBox> createState() => _MapBoxState();
}

class _MapBoxState extends State<MapBox> {
  final MapController _mapController = MapController();
  TileProvider? _tileProvider;
  String? _storeName;
  bool _isMapReady = false;
  String? _errorMessage;
  StreamSubscription<Position>? _positionStream;
  ll.LatLng? _currentLocation;
  List<ll.LatLng> _routePoints = [];
  static const double _autoSnapThreshold = 10.0;

  static const double _initialZoom = 20.0;
  double _currentZoom = _initialZoom;

  ll.LatLng? _lastValidLocation;
  static const double _maxJumpDistance = 20.0; // meters

  @override
  void initState() {
    super.initState();
    _initializeMap();
    connected(); // Start listening to connectivity changes
  }

  Future<void> _initializeMap() async {
    try {
      await _requestLocationPermission();
      await _getCurrentLocation();
      await _initializeTileProvider();

      _startLocationStream();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      throw Exception('Location permission denied');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = ll.LatLng(position.latitude, position.longitude);
      });
      if (_currentLocation != null) {
        moveMap(_currentLocation!);
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _startLocationStream() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Adjusted to make updates more frequent
      ),
    ).listen((Position position) {
      ll.LatLng newLocation = ll.LatLng(position.latitude, position.longitude);

      if (_isValidLocation(newLocation)) {
        setState(() {
          _lastValidLocation = newLocation;
          _currentLocation = newLocation;

          if (FFAppState().routeStarted) {
            _routePoints.add(_currentLocation!);
            // _checkAndSnapToStart(); // Commented out
            print("Added point: $_currentLocation");
            print("Total points: ${_routePoints.length}");
          }

          moveMap(_currentLocation!);
        });
      } else {
        print("Noise detected. Keeping the marker at the last valid location.");
      }
    });
  }

  bool _isValidLocation(ll.LatLng newLocation) {
    if (_lastValidLocation == null) {
      return true;
    }

    double distance = const ll.Distance().as(
      ll.LengthUnit.Meter,
      _lastValidLocation!,
      newLocation,
    );

    return distance <= _maxJumpDistance;
  }

  /*
  void _checkAndSnapToStart() {
    if (_routePoints.length > 1) {
      double distanceToStart = const ll.Distance().as(
        ll.LengthUnit.Meter,
        _routePoints.first,
        _routePoints.last,
      );

      if (distanceToStart <= _autoSnapThreshold) {
        _routePoints.add(_routePoints.first);
        FFAppState().routeStarted = false;
        _stopTracking();
        print("Automatically snapped to start and stopped tracking");
      }
    }
  }
  */

  Future<void> _initializeTileProvider() async {
    final stats = FMTC.FMTCRoot.stats;
    final stores = await stats.storesAvailable;

    print('Available stores: ${stores.length}');

    if (_currentLocation == null) {
      print('Current location is null');
      return;
    }

    ll.LatLng currentLocation =
        ll.LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
    print(
        'Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');

    bool storeFound = false;

    for (var store in stores) {
      print('Checking store: ${store.storeName}');
      final md = FMTC.FMTCStore(store.storeName).metadata;
      final metadata = await md.read;
      print('Metadata for ${store.storeName}: $metadata');

      if (metadata != null) {
        try {
          Map<String, num> regionData = {
            'region_south': _parseNum(metadata['region_south']),
            'region_north': _parseNum(metadata['region_north']),
            'region_west': _parseNum(metadata['region_west']),
            'region_east': _parseNum(metadata['region_east']),
          };
          print('Parsed region data: $regionData');

          if (_isLocationInRegion(currentLocation, regionData)) {
            _storeName = store.storeName;
            print('Matched store: $_storeName');
            storeFound = true;
            break;
          }
        } catch (e) {
          print('Error processing metadata for ${store.storeName}: $e');
        }
      } else {
        print('Metadata is null for ${store.storeName}');
      }
    }

    if (!storeFound) {
      print('No matching store found for the current location.');
    } else if (_storeName != null) {
      setState(() {
        _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
          settings: FMTC.FMTCTileProviderSettings(
            behavior: FMTC.CacheBehavior.cacheFirst,
          ),
        );
      });
      print('Tile provider initialized with store: $_storeName');
    } else {
      print('No store available to initialize tile provider');
    }
  }

  bool _isLocationInRegion(ll.LatLng location, Map<String, num> region) {
    print('Checking location: ${location.latitude}, ${location.longitude}');
    print('Region: $region');

    return location.latitude >= region['region_south']! &&
        location.latitude <= region['region_north']! &&
        location.longitude >= region['region_west']! &&
        location.longitude <= region['region_east']!;
  }

  num _parseNum(dynamic value) {
    if (value is num) {
      return value;
    } else if (value is String) {
      return num.parse(value);
    } else {
      throw FormatException('Cannot parse $value to num');
    }
  }

  void _showNoMapDataSnackBar() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This map is not downloaded.'),
        action: SnackBarAction(
          label: 'Download',
          onPressed: () {
            // Close the SnackBar
            ScaffoldMessenger.of(context).hideCurrentSnackBar();

            // Navigate to the download page
            context.pushNamed(
              'pcicMap',
              extra: <String, dynamic>{
                kTransitionInfoKey: const TransitionInfo(
                  hasTransition: true,
                  transitionType: PageTransitionType.rightToLeft,
                  duration: Duration(milliseconds: 200),
                ),
              },
            );
          },
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  void moveMap(ll.LatLng point) {
    _mapController.move(point, _currentZoom);
  }

  void zoomMap(double zoom) {
    setState(() {
      _currentZoom = zoom;
    });
    final currentCenter = _mapController.camera.center;
    _mapController.move(currentCenter, zoom);
  }

  double calculateAreaOfPolygon(List<ll.LatLng> points) {
    if (points.length < 3) {
      return 0.0;
    }
    double radius = 6378137.0;
    double area = 0.0;

    for (int i = 0; i < points.length; i++) {
      ll.LatLng p1 = points[i];
      ll.LatLng p2 = points[(i + 1) % points.length];

      double lat1 = p1.latitudeInRad;
      double lon1 = p1.longitudeInRad;
      double lat2 = p2.latitudeInRad;
      double lon2 = p2.longitudeInRad;

      double segmentArea = 2 *
          atan2(
            tan((lon2 - lon1) / 2) * tan((lat1 + lat2) / 2),
            1 + tan(lat1 / 2) * tan(lat2 / 2) * cos(lon1 - lon2),
          );
      area += segmentArea;
    }

    return (area * radius * radius).abs();
  }

  double calculateTotalDistance(List<ll.LatLng> points) {
    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += const ll.Distance().as(
        ll.LengthUnit.Meter,
        points[i],
        points[i + 1],
      );
    }
    return totalDistance;
  }

  void _startTracking() {
    setState(() {
      _routePoints.clear();
      if (_currentLocation != null) {
        _routePoints.add(_currentLocation!);
      }
    });
  }

  void _stopTracking() {
    if (_routePoints.isEmpty) return;

    print('Route completed. Total points: ${_routePoints.length}');

    double totalDistance = calculateTotalDistance(_routePoints);
    print('Total distance: $totalDistance meters');

    double area = 0.0;
    if (_routePoints.length >= 3) {
      area = calculateAreaOfPolygon(_routePoints);
      print('Area: $area square meters');
    }

    String routeCoordinatesString = _routePoints
        .map((point) => '${point.latitude},${point.longitude}')
        .join(' ');

    String lastCoord =
        '${_routePoints.last.latitude},${_routePoints.last.longitude}';
    print("Last coord: $lastCoord");

    String currentDateTime = DateTime.now().toIso8601String();
    print("Current date time: $currentDateTime");

    String areaInHectares = (area / 10000).toString();
    print("Area in hectares: $areaInHectares");

    String distanceInHectares = (totalDistance / 10000).toString();
    print("Distance in hectares: $distanceInHectares");

    saveGpx(
      widget.taskId ?? 'default_task_id',
      routeCoordinatesString,
      lastCoord,
      currentDateTime,
      areaInHectares,
      distanceInHectares,
    );

    setState(() {
      _routePoints.clear();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _positionStream
        ?.cancel(); // Ensure the stream is canceled when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Text('Error: $_errorMessage'),
      );
    }

    if (_currentLocation == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    if (!FFAppState().ONLINE && (_tileProvider == null || _storeName == null)) {
      return _buildOfflineMessageBox(context);
    }

    if (FFAppState().routeStarted && _routePoints.isEmpty) {
      _startTracking();
    } else if (!FFAppState().routeStarted && _routePoints.isNotEmpty) {
      _stopTracking();
    }

    return SizedBox(
      width: widget.width ?? MediaQuery.of(context).size.width,
      height: widget.height ?? MediaQuery.of(context).size.height,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation!,
          initialZoom: _currentZoom,
          minZoom: 18.5,
          maxZoom: 22,
          onMapReady: () {
            setState(() {
              _isMapReady = true;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
            additionalOptions: {
              'accessToken': widget.accessToken ?? '',
            },
            tileProvider: _tileProvider,
          ),
          if (_routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          CurrentLocationLayer(
            alignPositionOnUpdate: AlignOnUpdate.always,
            alignDirectionOnUpdate: AlignOnUpdate.never,
            style: LocationMarkerStyle(
              marker: DefaultLocationMarker(
                color: Colors.green,
              ),
              markerSize: const Size(12, 12),
              showAccuracyCircle: false,
              showHeadingSector: false,
              markerDirection: MarkerDirection.heading,
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: Column(
              children: [
                _buildIconButton(Icons.my_location, () {
                  if (_currentLocation != null) moveMap(_currentLocation!);
                }),
                SizedBox(height: 10),
                _buildIconButton(Icons.add, () => zoomMap(_currentZoom + 1)),
                SizedBox(height: 10),
                _buildIconButton(Icons.remove, () => zoomMap(_currentZoom - 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Color(0x7f0f1113),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.transparent, width: 1),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onPressed,
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    ),
  );
}

Widget _buildOfflineMessageBox(BuildContext context) {
  return Center(
    child: Container(
      width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
      constraints: BoxConstraints(maxWidth: 300), // Maximum width
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        children: [
          Icon(Icons.map_outlined, size: 50, color: Colors.white),
          SizedBox(height: 15),
          Text(
            'Map for your current location is not downloaded yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Download the map to use offline features',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.pushNamed(
                'pcicMap',
                extra: <String, dynamic>{
                  kTransitionInfoKey: const TransitionInfo(
                    hasTransition: true,
                    transitionType: PageTransitionType.rightToLeft,
                    duration: Duration(milliseconds: 200),
                  ),
                },
              );
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.white),
              foregroundColor: MaterialStateProperty.all(Colors.green),
              padding: MaterialStateProperty.all(
                  EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8.0), // Changed from 😎 to 8.0
                ),
              ),
            ),
            child: Text('Download Map'),
          ),
        ],
      ),
    ),
  );
}

// --------------------------------------------------- RECENT OLD CODE -----------------////////
// import 'dart:async';
// import 'dart:math';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

// class MapBox extends StatefulWidget {
//   const MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   }) : super(key: key);

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   TileProvider? _tileProvider;
//   String? _storeName;
//   bool _isMapReady = false;
//   String? _errorMessage;
//   StreamSubscription<Position>? _positionStream;
//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routePoints = [];
//   static const double _autoSnapThreshold = 10.0;

//   static const double _initialZoom = 20.0;
//   double _currentZoom = _initialZoom;

//   @override
//   void initState() {
//     super.initState();
//     _initializeMap();
//     connected(); // Start listening to connectivity changes
//   }

//   Future<void> _initializeMap() async {
//     try {
//       await _requestLocationPermission();
//       await _getCurrentLocation();
//       await _initializeTileProvider();

//       _startLocationStream();
//     } catch (e) {
//       setState(() {
//         _errorMessage = e.toString();
//       });
//     }
//   }

//   Future<void> _requestLocationPermission() async {
//     final status = await Permission.location.request();
//     if (!status.isGranted) {
//       throw Exception('Location permission denied');
//     }
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       setState(() {
//         _currentLocation = ll.LatLng(position.latitude, position.longitude);
//       });
//       if (_currentLocation != null) {
//         moveMap(_currentLocation!);
//       }
//     } catch (e) {
//       debugPrint('Error getting current location: $e');
//     }
//   }

//   void _startLocationStream() {
//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 10,
//       ),
//     ).listen((Position position) {
//       setState(() {
//         _currentLocation = ll.LatLng(position.latitude, position.longitude);
//         if (FFAppState().routeStarted) {
//           _routePoints.add(_currentLocation!);
//           _checkAndSnapToStart();
//           print("Added point: $_currentLocation");
//           print("Total points: ${_routePoints.length}");
//         }
//       });
//     });
//   }

//   void _checkAndSnapToStart() {
//     if (_routePoints.length > 1) {
//       double distanceToStart = const ll.Distance().as(
//         ll.LengthUnit.Meter,
//         _routePoints.first,
//         _routePoints.last,
//       );

//       if (distanceToStart <= _autoSnapThreshold) {
//         _routePoints.add(_routePoints.first);
//         FFAppState().routeStarted = false;
//         print("Automatically snapped to start and stopped tracking");
//       }
//     }
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     print('Available stores: ${stores.length}');

//     if (_currentLocation == null) {
//       print('Current location is null');
//       return;
//     }

//     ll.LatLng currentLocation =
//         ll.LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
//     print(
//         'Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');

//     bool storeFound = false;

//     for (var store in stores) {
//       print('Checking store: ${store.storeName}');
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       print('Metadata for ${store.storeName}: $metadata');

//       if (metadata != null) {
//         try {
//           Map<String, num> regionData = {
//             'region_south': _parseNum(metadata['region_south']),
//             'region_north': _parseNum(metadata['region_north']),
//             'region_west': _parseNum(metadata['region_west']),
//             'region_east': _parseNum(metadata['region_east']),
//           };
//           print('Parsed region data: $regionData');

//           if (_isLocationInRegion(currentLocation, regionData)) {
//             _storeName = store.storeName;
//             print('Matched store: $_storeName');
//             storeFound = true;
//             break;
//           }
//         } catch (e) {
//           print('Error processing metadata for ${store.storeName}: $e');
//         }
//       } else {
//         print('Metadata is null for ${store.storeName}');
//       }
//     }

//     if (!storeFound) {
//       print('No matching store found for the current location.');
//     } else if (_storeName != null) {
//       setState(() {
//         _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//           settings: FMTC.FMTCTileProviderSettings(
//             behavior: FMTC.CacheBehavior.cacheFirst,
//           ),
//         );
//       });
//       print('Tile provider initialized with store: $_storeName');
//     } else {
//       print('No store available to initialize tile provider');
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, num> region) {
//     print('Checking location: ${location.latitude}, ${location.longitude}');
//     print('Region: $region');

//     return location.latitude >= region['region_south']! &&
//         location.latitude <= region['region_north']! &&
//         location.longitude >= region['region_west']! &&
//         location.longitude <= region['region_east']!;
//   }

//   num _parseNum(dynamic value) {
//     if (value is num) {
//       return value;
//     } else if (value is String) {
//       return num.parse(value);
//     } else {
//       throw FormatException('Cannot parse $value to num');
//     }
//   }

//   void _showNoMapDataSnackBar() {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('This map is not downloaded.'),
//         action: SnackBarAction(
//           label: 'Download',
//           onPressed: () {
//             // Close the SnackBar
//             ScaffoldMessenger.of(context).hideCurrentSnackBar();

//             // Navigate to the download page
//             context.pushNamed(
//               'pcicMap',
//               extra: <String, dynamic>{
//                 kTransitionInfoKey: const TransitionInfo(
//                   hasTransition: true,
//                   transitionType: PageTransitionType.rightToLeft,
//                   duration: Duration(milliseconds: 200),
//                 ),
//               },
//             );
//           },
//         ),
//         duration: const Duration(seconds: 10),
//       ),
//     );
//   }

//   void moveMap(ll.LatLng point) {
//     _mapController.move(point, _currentZoom);
//   }

//   void zoomMap(double zoom) {
//     setState(() {
//       _currentZoom = zoom;
//     });
//     final currentCenter = _mapController.camera.center;
//     _mapController.move(currentCenter, zoom);
//   }

//   double calculateAreaOfPolygon(List<ll.LatLng> points) {
//     if (points.length < 3) {
//       return 0.0;
//     }
//     double radius = 6378137.0;
//     double area = 0.0;

//     for (int i = 0; i < points.length; i++) {
//       ll.LatLng p1 = points[i];
//       ll.LatLng p2 = points[(i + 1) % points.length];

//       double lat1 = p1.latitudeInRad;
//       double lon1 = p1.longitudeInRad;
//       double lat2 = p2.latitudeInRad;
//       double lon2 = p2.longitudeInRad;

//       double segmentArea = 2 *
//           atan2(
//             tan((lon2 - lon1) / 2) * tan((lat1 + lat2) / 2),
//             1 + tan(lat1 / 2) * tan(lat2 / 2) * cos(lon1 - lon2),
//           );
//       area += segmentArea;
//     }

//     return (area * radius * radius).abs();
//   }

//   double calculateTotalDistance(List<ll.LatLng> points) {
//     double totalDistance = 0.0;
//     for (int i = 0; i < points.length - 1; i++) {
//       totalDistance += const ll.Distance().as(
//         ll.LengthUnit.Meter,
//         points[i],
//         points[i + 1],
//       );
//     }
//     return totalDistance;
//   }

//   void _startTracking() {
//     setState(() {
//       _routePoints.clear();
//       if (_currentLocation != null) {
//         _routePoints.add(_currentLocation!);
//       }
//     });
//   }

//   void _stopTracking() {
//     if (_routePoints.isEmpty) return;

//     print('Route completed. Total points: ${_routePoints.length}');

//     double totalDistance = calculateTotalDistance(_routePoints);
//     print('Total distance: $totalDistance meters');

//     double area = 0.0;
//     if (_routePoints.length >= 3) {
//       area = calculateAreaOfPolygon(_routePoints);
//       print('Area: $area square meters');
//     }

//     String routeCoordinatesString = _routePoints
//         .map((point) => '${point.latitude},${point.longitude}')
//         .join(' ');

//     String lastCoord =
//         '${_routePoints.last.latitude},${_routePoints.last.longitude}';
//     print("Last coord: $lastCoord");

//     String currentDateTime = DateTime.now().toIso8601String();
//     print("Current date time: $currentDateTime");

//     String areaInHectares = (area / 10000).toString();
//     print("Area in hectares: $areaInHectares");

//     String distanceInHectares = (totalDistance / 10000).toString();
//     print("Distance in hectares: $distanceInHectares");

//     saveGpx(
//       widget.taskId ?? 'default_task_id',
//       routeCoordinatesString,
//       lastCoord,
//       currentDateTime,
//       areaInHectares,
//       distanceInHectares,
//     );

//     setState(() {
//       _routePoints.clear();
//     });
//   }

//   @override
//   void dispose() {
//     _mapController.dispose();
//     _positionStream?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_errorMessage != null) {
//       return Center(
//         child: Text('Error: $_errorMessage'),
//       );
//     }

//     if (_currentLocation == null) {
//       return Center(
//         child: CircularProgressIndicator(),
//       );
//     }
//     if (!FFAppState().ONLINE && (_tileProvider == null || _storeName == null)) {
//       return _buildOfflineMessageBox(context);
//     }

//     if (FFAppState().routeStarted && _routePoints.isEmpty) {
//       _startTracking();
//     } else if (!FFAppState().routeStarted && _routePoints.isNotEmpty) {
//       _stopTracking();
//     }

//     return SizedBox(
//       width: widget.width ?? MediaQuery.of(context).size.width,
//       height: widget.height ?? MediaQuery.of(context).size.height,
//       child: FlutterMap(
//         mapController: _mapController,
//         options: MapOptions(
//           initialCenter: _currentLocation!,
//           initialZoom: _currentZoom,
//           minZoom: 18.5,
//           maxZoom: 22,
//           onMapReady: () {
//             setState(() {
//               _isMapReady = true;
//             });
//           },
//         ),
//         children: [
//           TileLayer(
//             urlTemplate:
//                 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//             additionalOptions: {
//               'accessToken': widget.accessToken ?? '',
//             },
//             tileProvider: _tileProvider,
//           ),
//           if (_routePoints.isNotEmpty)
//             PolylineLayer(
//               polylines: [
//                 Polyline(
//                   points: _routePoints,
//                   strokeWidth: 4.0,
//                   color: Colors.blue,
//                 ),
//               ],
//             ),
//           CurrentLocationLayer(
//             alignPositionOnUpdate: AlignOnUpdate.always,
//             alignDirectionOnUpdate: AlignOnUpdate.never,
//             style: LocationMarkerStyle(
//               marker: DefaultLocationMarker(
//                 color: Colors.green,
//               ),
//               markerSize: const Size(12, 12),
//               showAccuracyCircle: false,
//               showHeadingSector: false,
//               markerDirection: MarkerDirection.heading,
//             ),
//           ),
//           Positioned(
//             top: 50,
//             right: 20,
//             child: Column(
//               children: [
//                 _buildIconButton(Icons.my_location, () {
//                   if (_currentLocation != null) moveMap(_currentLocation!);
//                 }),
//                 SizedBox(height: 10),
//                 _buildIconButton(Icons.add, () => zoomMap(_currentZoom + 1)),
//                 SizedBox(height: 10),
//                 _buildIconButton(Icons.remove, () => zoomMap(_currentZoom - 1)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
//   return Container(
//     width: 40,
//     height: 40,
//     decoration: BoxDecoration(
//       color: Color(0x7f0f1113),
//       shape: BoxShape.circle,
//       border: Border.all(color: Colors.transparent, width: 1),
//     ),
//     child: Material(
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(30),
//         onTap: onPressed,
//         child: Center(
//           child: Icon(
//             icon,
//             color: Colors.white,
//             size: 18,
//           ),
//         ),
//       ),
//     ),
//   );
// }

// Widget _buildOfflineMessageBox(BuildContext context) {
//   return Center(
//     child: Container(
//       width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
//       constraints: BoxConstraints(maxWidth: 300), // Maximum width
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.green,
//         borderRadius: BorderRadius.circular(10),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.5),
//             spreadRadius: 5,
//             blurRadius: 7,
//             offset: Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min, // Use minimum space needed
//         children: [
//           Icon(Icons.map_outlined, size: 50, color: Colors.white),
//           SizedBox(height: 15),
//           Text(
//             'Map for your current location is not downloaded yet',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//           SizedBox(height: 10),
//           Text(
//             'Download the map to use offline features',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.white,
//             ),
//           ),
//           SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () {
//               context.pushNamed(
//                 'pcicMap',
//                 extra: <String, dynamic>{
//                   kTransitionInfoKey: const TransitionInfo(
//                     hasTransition: true,
//                     transitionType: PageTransitionType.rightToLeft,
//                     duration: Duration(milliseconds: 200),
//                   ),
//                 },
//               );
//             },
//             style: ButtonStyle(
//               backgroundColor: MaterialStateProperty.all(Colors.white),
//               foregroundColor: MaterialStateProperty.all(Colors.green),
//               padding: MaterialStateProperty.all(
//                   EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
//               shape: MaterialStateProperty.all(
//                 RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//             ),
//             child: Text('Download Map'),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// ------------------------------ORIGINAL CODE ----------------//
// import 'dart:async';
// import 'dart:math';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

// class MapBox extends StatefulWidget {
//   const MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   }) : super(key: key);

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   TileProvider? _tileProvider;
//   String? _storeName;
//   bool _isMapReady = false;
//   String? _errorMessage;
//   StreamSubscription<Position>? _positionStream;
//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routePoints = [];

//   static const double _initialZoom = 20.0;
//   double _currentZoom = _initialZoom;

//   @override
//   void initState() {
//     super.initState();
//     _initializeMap();
//     connected(); // Start listening to connectivity changes
//   }

//   Future<void> _initializeMap() async {
//     try {
//       await _requestLocationPermission();
//       await _getCurrentLocation();
//       await _initializeTileProvider();

//       _startLocationStream();
//     } catch (e) {
//       setState(() {
//         _errorMessage = e.toString();
//       });
//     }
//   }

//   Future<void> _requestLocationPermission() async {
//     final status = await Permission.location.request();
//     if (!status.isGranted) {
//       throw Exception('Location permission denied');
//     }
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       setState(() {
//         _currentLocation = ll.LatLng(position.latitude, position.longitude);
//       });
//       if (_currentLocation != null) {
//         moveMap(_currentLocation!);
//       }
//     } catch (e) {
//       debugPrint('Error getting current location: $e');
//     }
//   }

//   void _startLocationStream() {
//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 10,
//       ),
//     ).listen((Position position) {
//       setState(() {
//         _currentLocation = ll.LatLng(position.latitude, position.longitude);
//         if (FFAppState().routeStarted) {
//           _routePoints.add(_currentLocation!);
//           print("Added point: $_currentLocation");
//           print("Total points: ${_routePoints.length}");
//         }
//       });
//     });
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     print('Available stores: ${stores.length}');

//     if (_currentLocation == null) {
//       print('Current location is null');
//       return;
//     }

//     ll.LatLng currentLocation =
//         ll.LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
//     print(
//         'Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');

//     bool storeFound = false;

//     for (var store in stores) {
//       print('Checking store: ${store.storeName}');
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       print('Metadata for ${store.storeName}: $metadata');

//       if (metadata != null) {
//         try {
//           Map<String, num> regionData = {
//             'region_south': _parseNum(metadata['region_south']),
//             'region_north': _parseNum(metadata['region_north']),
//             'region_west': _parseNum(metadata['region_west']),
//             'region_east': _parseNum(metadata['region_east']),
//           };
//           print('Parsed region data: $regionData');

//           if (_isLocationInRegion(currentLocation, regionData)) {
//             _storeName = store.storeName;
//             print('Matched store: $_storeName');
//             storeFound = true;
//             break;
//           }
//         } catch (e) {
//           print('Error processing metadata for ${store.storeName}: $e');
//         }
//       } else {
//         print('Metadata is null for ${store.storeName}');
//       }
//     }

//     if (!storeFound) {
//       print('No matching store found for the current location.');
//     } else if (_storeName != null) {
//       setState(() {
//         _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//           settings: FMTC.FMTCTileProviderSettings(
//             behavior: FMTC.CacheBehavior.cacheFirst,
//           ),
//         );
//       });
//       print('Tile provider initialized with store: $_storeName');
//     } else {
//       print('No store available to initialize tile provider');
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, num> region) {
//     print('Checking location: ${location.latitude}, ${location.longitude}');
//     print('Region: $region');

//     return location.latitude >= region['region_south']! &&
//         location.latitude <= region['region_north']! &&
//         location.longitude >= region['region_west']! &&
//         location.longitude <= region['region_east']!;
//   }

//   num _parseNum(dynamic value) {
//     if (value is num) {
//       return value;
//     } else if (value is String) {
//       return num.parse(value);
//     } else {
//       throw FormatException('Cannot parse $value to num');
//     }
//   }

//   void _showNoMapDataSnackBar() {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('This map is not downloaded.'),
//         action: SnackBarAction(
//           label: 'Download',
//           onPressed: () {
//             // Close the SnackBar
//             ScaffoldMessenger.of(context).hideCurrentSnackBar();

//             // Navigate to the download page
//             context.pushNamed(
//               'pcicMap',
//               extra: <String, dynamic>{
//                 kTransitionInfoKey: const TransitionInfo(
//                   hasTransition: true,
//                   transitionType: PageTransitionType.rightToLeft,
//                   duration: Duration(milliseconds: 200),
//                 ),
//               },
//             );
//           },
//         ),
//         duration: const Duration(seconds: 10),
//       ),
//     );
//   }

//   void moveMap(ll.LatLng point) {
//     _mapController.move(point, _currentZoom);
//   }

//   void zoomMap(double zoom) {
//     setState(() {
//       _currentZoom = zoom;
//     });
//     final currentCenter = _mapController.camera.center;
//     _mapController.move(currentCenter, zoom);
//   }

//   double calculateAreaOfPolygon(List<ll.LatLng> points) {
//     if (points.length < 3) {
//       return 0.0;
//     }
//     double radius = 6378137.0;
//     double area = 0.0;

//     for (int i = 0; i < points.length; i++) {
//       ll.LatLng p1 = points[i];
//       ll.LatLng p2 = points[(i + 1) % points.length];

//       double lat1 = p1.latitudeInRad;
//       double lon1 = p1.longitudeInRad;
//       double lat2 = p2.latitudeInRad;
//       double lon2 = p2.longitudeInRad;

//       double segmentArea = 2 *
//           atan2(
//             tan((lon2 - lon1) / 2) * tan((lat1 + lat2) / 2),
//             1 + tan(lat1 / 2) * tan(lat2 / 2) * cos(lon1 - lon2),
//           );
//       area += segmentArea;
//     }

//     return (area * radius * radius).abs();
//   }

//   double calculateTotalDistance(List<ll.LatLng> points) {
//     double totalDistance = 0.0;
//     for (int i = 0; i < points.length - 1; i++) {
//       totalDistance += const ll.Distance().as(
//         ll.LengthUnit.Meter,
//         points[i],
//         points[i + 1],
//       );
//     }
//     return totalDistance;
//   }

//   void _startTracking() {
//     setState(() {
//       _routePoints.clear();
//       if (_currentLocation != null) {
//         _routePoints.add(_currentLocation!);
//       }
//     });
//   }

//   void _stopTracking() {
//     if (_routePoints.isEmpty) return;

//     print('Route completed. Total points: ${_routePoints.length}');

//     double totalDistance = calculateTotalDistance(_routePoints);
//     print('Total distance: $totalDistance meters');

//     double area = 0.0;
//     if (_routePoints.length >= 3) {
//       area = calculateAreaOfPolygon(_routePoints);
//       print('Area: $area square meters');
//     }

//     String routeCoordinatesString = _routePoints
//         .map((point) => '${point.latitude},${point.longitude}')
//         .join(' ');

//     String lastCoord =
//         '${_routePoints.last.latitude},${_routePoints.last.longitude}';
//     print("Last coord: $lastCoord");

//     String currentDateTime = DateTime.now().toIso8601String();
//     print("Current date time: $currentDateTime");

//     String areaInHectares = (area / 10000).toString();
//     print("Area in hectares: $areaInHectares");

//     String distanceInHectares = (totalDistance / 10000).toString();
//     print("Distance in hectares: $distanceInHectares");

//     saveGpx(
//       widget.taskId ?? 'default_task_id',
//       routeCoordinatesString,
//       lastCoord,
//       currentDateTime,
//       areaInHectares,
//       distanceInHectares,
//     );

//     setState(() {
//       _routePoints.clear();
//     });
//   }

//   @override
//   void dispose() {
//     _mapController.dispose();
//     _positionStream?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_errorMessage != null) {
//       return Center(
//         child: Text('Error: $_errorMessage'),
//       );
//     }

//     if (_currentLocation == null) {
//       return Center(
//         child: CircularProgressIndicator(),
//       );
//     }
//     if (!FFAppState().ONLINE && (_tileProvider == null || _storeName == null)) {
//       return _buildOfflineMessageBox(context);
//     }

//     if (FFAppState().routeStarted && _routePoints.isEmpty) {
//       _startTracking();
//     } else if (!FFAppState().routeStarted && _routePoints.isNotEmpty) {
//       _stopTracking();
//     }

//     return SizedBox(
//       width: widget.width ?? MediaQuery.of(context).size.width,
//       height: widget.height ?? MediaQuery.of(context).size.height,
//       child: FlutterMap(
//         mapController: _mapController,
//         options: MapOptions(
//           initialCenter: _currentLocation!,
//           initialZoom: _currentZoom,
//           minZoom: 18.5,
//           maxZoom: 22,
//           onMapReady: () {
//             setState(() {
//               _isMapReady = true;
//             });
//           },
//         ),
//         children: [
//           TileLayer(
//             urlTemplate:
//                 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//             additionalOptions: {
//               'accessToken': widget.accessToken ?? '',
//             },
//             tileProvider: _tileProvider,
//           ),
//           if (_routePoints.isNotEmpty)
//             PolylineLayer(
//               polylines: [
//                 Polyline(
//                   points: _routePoints,
//                   strokeWidth: 4.0,
//                   color: Colors.blue,
//                 ),
//               ],
//             ),
//           CurrentLocationLayer(
//             alignPositionOnUpdate: AlignOnUpdate.always,
//             alignDirectionOnUpdate: AlignOnUpdate.never,
//             style: LocationMarkerStyle(
//               marker: DefaultLocationMarker(
//                 color: Colors.green,
//               ),
//               markerSize: const Size(12, 12),
//               showAccuracyCircle: false,
//               showHeadingSector: false,
//               markerDirection: MarkerDirection.heading,
//             ),
//           ),
//           Positioned(
//             top: 50,
//             right: 20,
//             child: Column(
//               children: [
//                 _buildIconButton(Icons.my_location, () {
//                   if (_currentLocation != null) moveMap(_currentLocation!);
//                 }),
//                 SizedBox(height: 10),
//                 _buildIconButton(Icons.add, () => zoomMap(_currentZoom + 1)),
//                 SizedBox(height: 10),
//                 _buildIconButton(Icons.remove, () => zoomMap(_currentZoom - 1)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
//   return Container(
//     width: 40,
//     height: 40,
//     decoration: BoxDecoration(
//       color: Color(0x7f0f1113),
//       shape: BoxShape.circle,
//       border: Border.all(color: Colors.transparent, width: 1),
//     ),
//     child: Material(
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(30),
//         onTap: onPressed,
//         child: Center(
//           child: Icon(
//             icon,
//             color: Colors.white,
//             size: 18,
//           ),
//         ),
//       ),
//     ),
//   );
// }

// Widget _buildOfflineMessageBox(BuildContext context) {
//   return Center(
//     child: Container(
//       width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
//       constraints: BoxConstraints(maxWidth: 300), // Maximum width
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.green,
//         borderRadius: BorderRadius.circular(10),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.5),
//             spreadRadius: 5,
//             blurRadius: 7,
//             offset: Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min, // Use minimum space needed
//         children: [
//           Icon(Icons.map_outlined, size: 50, color: Colors.white),
//           SizedBox(height: 15),
//           Text(
//             'Map for your current location is not downloaded yet',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//           SizedBox(height: 10),
//           Text(
//             'Download the map to use offline features',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.white,
//             ),
//           ),
//           SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () {
//               context.pushNamed(
//                 'pcicMap',
//                 extra: <String, dynamic>{
//                   kTransitionInfoKey: const TransitionInfo(
//                     hasTransition: true,
//                     transitionType: PageTransitionType.rightToLeft,
//                     duration: Duration(milliseconds: 200),
//                   ),
//                 },
//               );
//             },
//             style: ButtonStyle(
//               backgroundColor: MaterialStateProperty.all(Colors.white),
//               foregroundColor: MaterialStateProperty.all(Colors.green),
//               padding: MaterialStateProperty.all(
//                   EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
//               shape: MaterialStateProperty.all(
//                 RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//             ),
//             child: Text('Download Map'),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// //The unknown well yeeeeeeeett
// import 'dart:async';
// import 'dart:math';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:connectivity_plus/connectivity_plus.dart';

// class MapBox extends StatefulWidget {
//   const MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   }) : super(key: key);

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   StreamSubscription<Position>? _positionStreamSubscription;

//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routeCoordinates = [];
//   ll.LatLng? _startingPosition;
//   final ll.Distance _distance = ll.Distance();

//   bool _isTracking = false;
//   bool _isMapReady = false;

//   TileProvider? _tileProvider;
//   String? _storeName;

//   String? _errorMessage;

//   static const double _currentZoom = 19.0;
//   static const int _positionStreamIntervalMs = 100;
//   static const int _initialPositionSamples = 50;
//   static const double _highAccuracyThreshold = 10.0;
//   static const double _stationarySpeedThreshold = 0.1;
//   static const double _significantMovementThreshold = 0.5;
//   static const int _stationaryWindowSize = 20;

//   late SimpleKalmanFilter _latFilter;
//   late SimpleKalmanFilter _lonFilter;

//   List<Position> _recentPositions = [];

//   ll.LatLng _averagePosition = ll.LatLng(0, 0);
//   bool _isStationary = true;

//   DateTime _lastUpdateTime = DateTime.now();
//   double? _currentHeading;
//   ll.LatLng? _lastFilteredLocation;

//   @override
//   void initState() {
//     super.initState();
//     _latFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _lonFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _checkConnectivity();
//     _initializeTileProvider();
//     _initializeLocation();
//   }

//   Future<void> _checkConnectivity() async {
//     var connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       setState(() {
//         _errorMessage = "No internet connection.";
//       });
//     }
//   }

//   Future<void> _initializeLocation() async {
//     try {
//       await _checkLocationPermission();
//       await _checkLocationAccuracy();

//       Position initialPosition = await _getAccuratePosition();

//       if (!mounted) return;

//       setState(() {
//         _currentLocation =
//             ll.LatLng(initialPosition.latitude, initialPosition.longitude);
//         _routeCoordinates.add(_currentLocation!);
//         if (_isMapReady) {
//           _mapController.move(_currentLocation!, _currentZoom);
//         }
//       });

//       _startLocationStream();
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "Initialization error: $e";
//         });
//       }
//     }
//   }

//   Future<Position> _getAccuratePosition() async {
//     List<Position> samples = [];
//     for (int i = 0; i < _initialPositionSamples; i++) {
//       Position position = await _getCurrentPositionWithRetry();
//       samples.add(position);
//       await Future.delayed(Duration(milliseconds: 200));
//     }

//     double sumLat = 0, sumLon = 0, sumAcc = 0;
//     for (var pos in samples) {
//       sumLat += pos.latitude;
//       sumLon += pos.longitude;
//       sumAcc += pos.accuracy;
//     }

//     double avgLat = sumLat / _initialPositionSamples;
//     double avgLon = sumLon / _initialPositionSamples;
//     double avgAcc = sumAcc / _initialPositionSamples;

//     _latFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01
//     _lonFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01

//     return Position(
//       latitude: avgLat,
//       longitude: avgLon,
//       timestamp: DateTime.now(),
//       accuracy: avgAcc,
//       altitude: samples.last.altitude,
//       heading: samples.last.heading,
//       speed: samples.last.speed,
//       speedAccuracy: samples.last.speedAccuracy,
//       altitudeAccuracy: samples.last.altitudeAccuracy ?? 0,
//       headingAccuracy: samples.last.headingAccuracy ?? 0,
//     );
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     if (stores.isEmpty) {
//       print("No stores available");
//       return;
//     }

//     Position position = await _getCurrentPositionWithRetry();
//     if (!mounted) return;
//     ll.LatLng currentLocation =
//         ll.LatLng(position.latitude, position.longitude);

//     for (var store in stores) {
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       if (metadata != null && _isLocationInRegion(currentLocation, metadata)) {
//         _storeName = store.storeName;
//         break;
//       }
//     }

//     _storeName ??= stores.isNotEmpty ? stores[0].storeName : null;

//     if (_storeName != null) {
//       setState(() {
//         _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//           settings: FMTC.FMTCTileProviderSettings(
//             behavior: FMTC.CacheBehavior.cacheFirst,
//           ),
//         );
//       });
//     } else {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "No suitable tile store found.";
//         });
//       }
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, dynamic> region) {
//     return location.latitude >= region['region_south'] &&
//         location.latitude <= region['region_north'] &&
//         location.longitude >= region['region_west'] &&
//         location.longitude <= region['region_east'];
//   }

//   Future<void> _checkLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('Location services are disabled.');

//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Location permissions are denied');
//       }
//     }
//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Location permissions are permanently denied');
//     }
//   }

//   Future<void> _checkLocationAccuracy() async {
//     try {
//       LocationAccuracyStatus accuracy = await Geolocator.getLocationAccuracy();
//       if (accuracy == LocationAccuracyStatus.reduced && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Please enable precise location for better accuracy'),
//             action: SnackBarAction(
//               label: 'Settings',
//               onPressed: () {
//                 Geolocator.openAppSettings();
//               },
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error checking location accuracy: $e');
//     }
//   }

//   Future<Position> _getCurrentPositionWithRetry({int retries = 0}) async {
//     try {
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.best,
//         timeLimit: Duration(seconds: 10),
//       );
//     } catch (e) {
//       if (retries < 3) {
//         await Future.delayed(Duration(seconds: 2));
//         return _getCurrentPositionWithRetry(retries: retries + 1);
//       } else {
//         _showSnackbar("Failed to get accurate location, using best effort.");
//         return await Geolocator.getLastKnownPosition() ??
//             Position(
//               longitude: 0.0,
//               latitude: 0.0,
//               timestamp: DateTime.now(),
//               accuracy: 0.0,
//               altitude: 0.0,
//               heading: 0.0,
//               speed: 0.0,
//               speedAccuracy: 0.0,
//               altitudeAccuracy: 0.0,
//               headingAccuracy: 0.0,
//             );
//       }
//     }
//   }

//   Future<bool> _isGpsEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }

//   void _startLocationStream() {
//     final LocationSettings locationSettings = AndroidSettings(
//       accuracy: LocationAccuracy.bestForNavigation,
//       distanceFilter: 1,
//       forceLocationManager: false,
//       intervalDuration: Duration(milliseconds: _positionStreamIntervalMs),
//     );

//     _positionStreamSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position position) {
//         if (mounted) {
//           _processNewPosition(position);
//         }
//       },
//       onError: (error) {
//         print("Location stream error: $error");
//         _restartLocationStream();
//       },
//     );
//   }

//   void _restartLocationStream() {
//     _positionStreamSubscription?.cancel();
//     Future.delayed(Duration(seconds: 1), _startLocationStream);
//   }

//   void _processNewPosition(Position position) {
//     // Apply Kalman filter for the marker position
//     double filteredLat = _latFilter.filter(position.latitude);
//     double filteredLon = _lonFilter.filter(position.longitude);
//     ll.LatLng filteredLocation = ll.LatLng(filteredLat, filteredLon);

//     // Use raw coordinates for the route
//     ll.LatLng rawLocation = ll.LatLng(position.latitude, position.longitude);

//     _updatePosition(
//         filteredLocation, rawLocation, position.heading, position.speed);
//   }

//   void _updatePosition(ll.LatLng filteredLocation, ll.LatLng rawLocation,
//       double heading, double speed) {
//     setState(() {
//       _currentLocation =
//           filteredLocation; // Use filtered location for the marker
//       _currentHeading = heading;
//       _lastFilteredLocation = filteredLocation;
//       _lastUpdateTime = DateTime.now();

//       if (_isMapReady && _shouldRecenterMap()) {
//         _mapController.move(_currentLocation!, _currentZoom);
//         if (speed > _stationarySpeedThreshold) {
//           _mapController.rotate(heading);
//         }
//       }

//       if (_isTracking) {
//         _addToRoute(rawLocation); // Use raw location for the route
//       }
//     });
//   }

//   void _addToRoute(ll.LatLng newLocation) {
//     // Always add the new raw location to make the route more detailed
//     setState(() {
//       _routeCoordinates.add(newLocation);
//     });
//   }

//   Future<void> _startTracking() async {
//     if (_currentLocation != null && !_isTracking) {
//       bool gpsEnabled = await _isGpsEnabled();
//       if (!gpsEnabled) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text(
//                 'GPS is not enabled. Please turn on GPS to start tracking.'),
//           ));
//         }
//         FFAppState().routeStarted = false;
//         return;
//       }

//       try {
//         setState(() {
//           _isTracking = true;
//           _routeCoordinates.clear();
//           _startingPosition = _currentLocation;
//         });

//         Position startPosition = await _getAccuratePosition();
//         if (!mounted) return;

//         setState(() {
//           _startingPosition =
//               ll.LatLng(startPosition.latitude, startPosition.longitude);
//           _routeCoordinates.add(_startingPosition!);
//         });

//         FFAppState().routeStarted = true;
//       } catch (e) {
//         if (mounted) {
//           setState(() {
//             _isTracking = false;
//             _errorMessage = "Failed to start tracking: $e";
//           });
//         }
//         FFAppState().routeStarted = false;
//       }
//     }
//   }

//   void _completeTracking() {
//     if (_isTracking) {
//       setState(() {
//         _isTracking = false;
//         if (_routeCoordinates.isNotEmpty &&
//             _routeCoordinates.first != _routeCoordinates.last) {
//           _routeCoordinates.add(_routeCoordinates.first);
//         }
//       });

//       List<LatLng> convertedCoordinates = _routeCoordinates
//           .map((coord) => LatLng(coord.latitude, coord.longitude))
//           .toList();

//       debugPrint('Converted coordinates: $convertedCoordinates');
//       saveGpx(widget.taskId ?? 'default_task_id', convertedCoordinates);

//       FFAppState().routeStarted = false;
//     }
//   }

//   void _recenterMap() {
//     if (_currentLocation != null && _isMapReady) {
//       _mapController.move(_currentLocation!, _currentZoom);
//     }
//   }

//   bool _shouldRecenterMap() {
//     if (!_isMapReady || _currentLocation == null) return false;

//     final mapBounds = LatLngBounds.fromPoints(
//       [
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, -1, -1),
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, 1, 1),
//       ],
//     );

//     final currentPoint =
//         _mapController.camera.latLngToScreenPoint(_currentLocation!);

//     return currentPoint == null || !mapBounds.contains(_currentLocation!);
//   }

//   ll.LatLng _calculateOffset(
//       ll.LatLng center, double zoom, double xOffset, double yOffset) {
//     final double scaleFactor = 0.01 / zoom;
//     return ll.LatLng(
//       center.latitude + (scaleFactor * yOffset),
//       center.longitude + (scaleFactor * xOffset),
//     );
//   }

//   void _showSnackbar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = FFAppState();

//     if (appState.routeStarted && !_isTracking) {
//       _startTracking();
//     }

//     if (!appState.routeStarted && _isTracking) {
//       _completeTracking();
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('Error: $_errorMessage'),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _errorMessage = null;
//                 });
//                 _initializeLocation();
//               },
//               child: Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (_currentLocation == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Stack(
//       children: [
//         SizedBox(
//           width: widget.width ?? MediaQuery.of(context).size.width,
//           height: widget.height ?? MediaQuery.of(context).size.height,
//           child: FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _currentLocation!,
//               initialZoom: _currentZoom,
//               minZoom: 18,
//               maxZoom: 22,
//               onMapReady: () {
//                 setState(() {
//                   _isMapReady = true;
//                   if (_currentLocation != null) {
//                     _mapController.move(_currentLocation!, _currentZoom);
//                   }
//                 });
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate:
//                     'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//                 additionalOptions: {
//                   'accessToken': widget.accessToken ?? '',
//                 },
//                 tileProvider: _tileProvider,
//               ),
//               CurrentLocationLayer(
//                 followOnLocationUpdate: FollowOnLocationUpdate.always,
//                 style: LocationMarkerStyle(
//                   marker: const DefaultLocationMarker(color: Colors.green),
//                   markerSize: const Size(12, 12),
//                   markerDirection: MarkerDirection.heading,
//                   accuracyCircleColor: Colors.green.withOpacity(0.2),
//                   headingSectorColor: Colors.green.withOpacity(0.8),
//                   headingSectorRadius: 60,
//                 ),
//                 moveAnimationDuration: Duration.zero,
//               ),
//               if (_routeCoordinates.isNotEmpty &&
//                   (appState.routeStarted || _isTracking))
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routeCoordinates,
//                       strokeWidth: 3.0,
//                       color: Colors.blue,
//                     ),
//                   ],
//                 ),
//               MarkerLayer(
//                 markers: _startingPosition != null
//                     ? [
//                         Marker(
//                           point: _startingPosition!,
//                           child: Icon(
//                             Icons.pin_drop,
//                             color: Colors.red,
//                             size: 10.0,
//                           ),
//                         ),
//                       ]
//                     : [],
//               ),
//             ],
//           ),
//         ),
//         Positioned(
//           top: 50,
//           right: 20,
//           child: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Color(0x7f0f1113),
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.transparent, width: 1),
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(30),
//                 onTap: _recenterMap,
//                 child: Center(
//                   child: Icon(
//                     Icons.my_location_outlined,
//                     color: Colors.white,
//                     size: 24,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class SimpleKalmanFilter {
//   double _e;
//   double _q;
//   double? _lastEstimate;

//   SimpleKalmanFilter({required double e, required double q})
//       : _e = e,
//         _q = q;

//   double filter(double measurement) {
//     if (_lastEstimate == null) {
//       _lastEstimate = measurement;
//       return measurement;
//     }

//     double prediction = _lastEstimate!;
//     double kalmanGain = _e / (_e + _q);
//     double estimate = prediction + kalmanGain * (measurement - prediction);

//     _e = (1 - kalmanGain) * _e + ((_lastEstimate! - estimate).abs()) * _q;
//     _lastEstimate = estimate;

//     return estimate;
//   }
// }

// import 'dart:async';
// import 'dart:math';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:connectivity_plus/connectivity_plus.dart';

// class MapBox extends StatefulWidget {
//   const MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   }) : super(key: key);

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   StreamSubscription<Position>? _positionStreamSubscription;

//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routeCoordinates = [];
//   ll.LatLng? _startingPosition;
//   final ll.Distance _distance = ll.Distance();

//   bool _isTracking = false;
//   bool _isMapReady = false;

//   TileProvider? _tileProvider;
//   String? _storeName;

//   String? _errorMessage;

//   static const double _currentZoom = 19.0;
//   static const int _positionStreamIntervalMs = 100;
//   static const int _initialPositionSamples = 20;
//   static const double _highAccuracyThreshold = 10.0;
//   static const double _stationarySpeedThreshold = 0.1;
//   static const double _significantMovementThreshold = 0.5;
//   static const int _stationaryWindowSize = 20;

//   late SimpleKalmanFilter _latFilter;
//   late SimpleKalmanFilter _lonFilter;

//   List<Position> _recentPositions = [];

//   ll.LatLng _averagePosition = ll.LatLng(0, 0);
//   bool _isStationary = true;

//   DateTime _lastUpdateTime = DateTime.now();
//   double? _currentHeading;
//   ll.LatLng? _lastFilteredLocation;

//   @override
//   void initState() {
//     super.initState();
//     _latFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _lonFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _checkConnectivity();
//     _initializeTileProvider();
//     _initializeLocation();
//   }

//   Future<void> _checkConnectivity() async {
//     var connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       setState(() {
//         _errorMessage = "No internet connection.";
//       });
//     }
//   }

//   Future<void> _initializeLocation() async {
//     try {
//       await _checkLocationPermission();
//       await _checkLocationAccuracy();

//       Position initialPosition = await _getAccuratePosition();

//       if (!mounted) return;

//       setState(() {
//         _currentLocation =
//             ll.LatLng(initialPosition.latitude, initialPosition.longitude);
//         _routeCoordinates.add(_currentLocation!);
//         if (_isMapReady) {
//           _mapController.move(_currentLocation!, _currentZoom);
//         }
//       });

//       _startLocationStream();
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "Initialization error: $e";
//         });
//       }
//     }
//   }

//   Future<Position> _getAccuratePosition() async {
//     List<Position> samples = [];
//     for (int i = 0; i < _initialPositionSamples; i++) {
//       Position position = await _getCurrentPositionWithRetry();
//       samples.add(position);
//       await Future.delayed(Duration(milliseconds: 200));
//     }

//     double sumLat = 0, sumLon = 0, sumAcc = 0;
//     for (var pos in samples) {
//       sumLat += pos.latitude;
//       sumLon += pos.longitude;
//       sumAcc += pos.accuracy;
//     }

//     double avgLat = sumLat / _initialPositionSamples;
//     double avgLon = sumLon / _initialPositionSamples;
//     double avgAcc = sumAcc / _initialPositionSamples;

//     _latFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01
//     _lonFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01

//     return Position(
//       latitude: avgLat,
//       longitude: avgLon,
//       timestamp: DateTime.now(),
//       accuracy: avgAcc,
//       altitude: samples.last.altitude,
//       heading: samples.last.heading,
//       speed: samples.last.speed,
//       speedAccuracy: samples.last.speedAccuracy,
//       altitudeAccuracy: samples.last.altitudeAccuracy ?? 0,
//       headingAccuracy: samples.last.headingAccuracy ?? 0,
//     );
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     if (stores.isEmpty) {
//       print("No stores available");
//       return;
//     }

//     Position position = await _getCurrentPositionWithRetry();
//     if (!mounted) return;
//     ll.LatLng currentLocation =
//         ll.LatLng(position.latitude, position.longitude);

//     for (var store in stores) {
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       if (metadata != null && _isLocationInRegion(currentLocation, metadata)) {
//         _storeName = store.storeName;
//         break;
//       }
//     }

//     _storeName ??= stores.isNotEmpty ? stores[0].storeName : null;

//     if (_storeName != null) {
//       setState(() {
//         _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//           settings: FMTC.FMTCTileProviderSettings(
//             behavior: FMTC.CacheBehavior.cacheFirst,
//           ),
//         );
//       });
//     } else {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "No suitable tile store found.";
//         });
//       }
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, dynamic> region) {
//     return location.latitude >= region['region_south'] &&
//         location.latitude <= region['region_north'] &&
//         location.longitude >= region['region_west'] &&
//         location.longitude <= region['region_east'];
//   }

//   Future<void> _checkLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('Location services are disabled.');

//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Location permissions are denied');
//       }
//     }
//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Location permissions are permanently denied');
//     }
//   }

//   Future<void> _checkLocationAccuracy() async {
//     try {
//       LocationAccuracyStatus accuracy = await Geolocator.getLocationAccuracy();
//       if (accuracy == LocationAccuracyStatus.reduced && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Please enable precise location for better accuracy'),
//             action: SnackBarAction(
//               label: 'Settings',
//               onPressed: () {
//                 Geolocator.openAppSettings();
//               },
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error checking location accuracy: $e');
//     }
//   }

//   Future<Position> _getCurrentPositionWithRetry({int retries = 0}) async {
//     try {
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.best,
//         timeLimit: Duration(seconds: 10),
//       );
//     } catch (e) {
//       if (retries < 3) {
//         await Future.delayed(Duration(seconds: 2));
//         return _getCurrentPositionWithRetry(retries: retries + 1);
//       } else {
//         _showSnackbar("Failed to get accurate location, using best effort.");
//         return await Geolocator.getLastKnownPosition() ??
//             Position(
//               longitude: 0.0,
//               latitude: 0.0,
//               timestamp: DateTime.now(),
//               accuracy: 0.0,
//               altitude: 0.0,
//               heading: 0.0,
//               speed: 0.0,
//               speedAccuracy: 0.0,
//               altitudeAccuracy: 0.0,
//               headingAccuracy: 0.0,
//             );
//       }
//     }
//   }

//   Future<bool> _isGpsEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }

//   void _startLocationStream() {
//     final LocationSettings locationSettings = AndroidSettings(
//       accuracy: LocationAccuracy.bestForNavigation,
//       distanceFilter: 1,
//       forceLocationManager: false,
//       intervalDuration: Duration(milliseconds: _positionStreamIntervalMs),
//     );

//     _positionStreamSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position position) {
//         if (mounted) {
//           _processNewPosition(position);
//         }
//       },
//       onError: (error) {
//         print("Location stream error: $error");
//         _restartLocationStream();
//       },
//     );
//   }

//   void _restartLocationStream() {
//     _positionStreamSubscription?.cancel();
//     Future.delayed(Duration(seconds: 1), _startLocationStream);
//   }

//   void _processNewPosition(Position position) {
//     // Apply Kalman filter for the marker position
//     double filteredLat = _latFilter.filter(position.latitude);
//     double filteredLon = _lonFilter.filter(position.longitude);
//     ll.LatLng filteredLocation = ll.LatLng(filteredLat, filteredLon);

//     // Use raw coordinates for the route
//     ll.LatLng rawLocation = ll.LatLng(position.latitude, position.longitude);

//     _updatePosition(
//         filteredLocation, rawLocation, position.heading, position.speed);
//   }

//   void _updatePosition(ll.LatLng filteredLocation, ll.LatLng rawLocation,
//       double heading, double speed) {
//     setState(() {
//       _currentLocation =
//           filteredLocation; // Use filtered location for the marker
//       _currentHeading = heading;
//       _lastFilteredLocation = filteredLocation;
//       _lastUpdateTime = DateTime.now();

//       if (_isMapReady && _shouldRecenterMap()) {
//         _mapController.move(_currentLocation!, _currentZoom);
//         if (speed > _stationarySpeedThreshold) {
//           _mapController.rotate(heading);
//         }
//       }

//       if (_isTracking) {
//         _addToRoute(rawLocation); // Use raw location for the route
//       }
//     });
//   }

//   void _addToRoute(ll.LatLng newLocation) {
//     // Always add the new raw location to make the route more detailed
//     setState(() {
//       _routeCoordinates.add(newLocation);
//     });
//   }

//   Future<void> _startTracking() async {
//     if (_currentLocation != null && !_isTracking) {
//       bool gpsEnabled = await _isGpsEnabled();
//       if (!gpsEnabled) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text(
//                 'GPS is not enabled. Please turn on GPS to start tracking.'),
//           ));
//         }
//         FFAppState().routeStarted = false;
//         return;
//       }

//       try {
//         setState(() {
//           _isTracking = true;
//           _routeCoordinates.clear();
//           _startingPosition = _currentLocation;
//         });

//         Position startPosition = await _getAccuratePosition();
//         if (!mounted) return;

//         setState(() {
//           _startingPosition =
//               ll.LatLng(startPosition.latitude, startPosition.longitude);
//           _routeCoordinates.add(_startingPosition!);
//         });

//         FFAppState().routeStarted = true;
//       } catch (e) {
//         if (mounted) {
//           setState(() {
//             _isTracking = false;
//             _errorMessage = "Failed to start tracking: $e";
//           });
//         }
//         FFAppState().routeStarted = false;
//       }
//     }
//   }

//   void _completeTracking() {
//     if (_isTracking) {
//       setState(() {
//         _isTracking = false;
//         if (_routeCoordinates.isNotEmpty &&
//             _routeCoordinates.first != _routeCoordinates.last) {
//           _routeCoordinates.add(_routeCoordinates.first);
//         }
//       });

//       List<LatLng> convertedCoordinates = _routeCoordinates
//           .map((coord) => LatLng(coord.latitude, coord.longitude))
//           .toList();

//       debugPrint('Converted coordinates: $convertedCoordinates');
//       saveGpx(widget.taskId ?? 'default_task_id', convertedCoordinates);

//       FFAppState().routeStarted = false;
//     }
//   }

//   void _recenterMap() {
//     if (_currentLocation != null && _isMapReady) {
//       _mapController.move(_currentLocation!, _currentZoom);
//     }
//   }

//   bool _shouldRecenterMap() {
//     if (!_isMapReady || _currentLocation == null) return false;

//     final mapBounds = LatLngBounds.fromPoints(
//       [
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, -1, -1),
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, 1, 1),
//       ],
//     );

//     final currentPoint =
//         _mapController.camera.latLngToScreenPoint(_currentLocation!);

//     return currentPoint == null || !mapBounds.contains(_currentLocation!);
//   }

//   ll.LatLng _calculateOffset(
//       ll.LatLng center, double zoom, double xOffset, double yOffset) {
//     final double scaleFactor = 0.01 / zoom;
//     return ll.LatLng(
//       center.latitude + (scaleFactor * yOffset),
//       center.longitude + (scaleFactor * xOffset),
//     );
//   }

//   void _showSnackbar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = FFAppState();

//     if (appState.routeStarted && !_isTracking) {
//       _startTracking();
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('Error: $_errorMessage'),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _errorMessage = null;
//                 });
//                 _initializeLocation();
//               },
//               child: Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (_currentLocation == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Stack(
//       children: [
//         SizedBox(
//           width: widget.width ?? MediaQuery.of(context).size.width,
//           height: widget.height ?? MediaQuery.of(context).size.height,
//           child: FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _currentLocation!,
//               initialZoom: _currentZoom,
//               minZoom: 18,
//               maxZoom: 22,
//               onMapReady: () {
//                 setState(() {
//                   _isMapReady = true;
//                   if (_currentLocation != null) {
//                     _mapController.move(_currentLocation!, _currentZoom);
//                   }
//                 });
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate:
//                     'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//                 additionalOptions: {
//                   'accessToken': widget.accessToken ?? '',
//                 },
//                 tileProvider: _tileProvider,
//               ),
//               CurrentLocationLayer(
//                 followOnLocationUpdate: FollowOnLocationUpdate.always,
//                 style: LocationMarkerStyle(
//                   marker: const DefaultLocationMarker(color: Colors.green),
//                   markerSize: const Size(12, 12),
//                   markerDirection: MarkerDirection.heading,
//                   accuracyCircleColor: Colors.green.withOpacity(0.2),
//                   headingSectorColor: Colors.green.withOpacity(0.8),
//                   headingSectorRadius: 60,
//                 ),
//                 moveAnimationDuration: Duration.zero,
//               ),
//               if (_routeCoordinates.isNotEmpty &&
//                   (appState.routeStarted || _isTracking))
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routeCoordinates,
//                       strokeWidth: 4.0,
//                       color: Colors.blue,
//                     ),
//                   ],
//                 ),
//               MarkerLayer(
//                 markers: _startingPosition != null
//                     ? [
//                         Marker(
//                           point: _startingPosition!,
//                           child: Icon(Icons.star, color: Colors.red),
//                         ),
//                       ]
//                     : [],
//               ),
//             ],
//           ),
//         ),
//         Positioned(
//           top: 50,
//           right: 20,
//           child: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Color(0x7f0f1113),
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.transparent, width: 1),
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(30),
//                 onTap: _recenterMap,
//                 child: Center(
//                   child: Icon(
//                     Icons.my_location_outlined,
//                     color: Colors.white,
//                     size: 24,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class SimpleKalmanFilter {
//   double _e;
//   double _q;
//   double? _lastEstimate;

//   SimpleKalmanFilter({required double e, required double q})
//       : _e = e,
//         _q = q;

//   double filter(double measurement) {
//     if (_lastEstimate == null) {
//       _lastEstimate = measurement;
//       return measurement;
//     }

//     double prediction = _lastEstimate!;
//     double kalmanGain = _e / (_e + _q);
//     double estimate = prediction + kalmanGain * (measurement - prediction);

//     _e = (1 - kalmanGain) * _e + ((_lastEstimate! - estimate).abs()) * _q;
//     _lastEstimate = estimate;

//     return estimate;
//   }
// }
// -----------------------------FOR BACK UP -------------------------------//

// void _processNewPosition(Position position) {
//   print('Current position accuracy: ${position.accuracy} meters');
//   if (position.accuracy > _highAccuracyThreshold) {
//     return;
//   }

//   double filteredLat = _latitudeFilter!.update(position.latitude);
//   double filteredLon = _longitudeFilter!.update(position.longitude);
//   ll.LatLng newLocation = ll.LatLng(filteredLat, filteredLon);

//   _recentPositions.add(position);
//   if (_recentPositions.length > _stationaryWindowSize) {
//     _recentPositions.removeAt(0);
//   }

//   _isStationary = _checkIfStationary();

//   if (_isStationary) {
//     _updatePositionStationary(newLocation);
//   } else {
//     _updatePositionMoving(newLocation, position.heading, position.speed);
//   }

//   if (_isTracking || FFAppState().routeStarted) {
//     _addToRoute(newLocation);
//   }
// }

// void _updatePosition(ll.LatLng location, double heading) {
//   setState(() {
//     _currentLocation = location;
//     _currentHeading = heading;
//     if (_isMapReady && _shouldRecenterMap()) {
//       _mapController.move(_currentLocation!, _currentZoom);
//       if (!_isStationary) {
//         _mapController.rotate(heading);
//       }
//     }
//   });
// }

// void _updatePositionMoving(
//     ll.LatLng newLocation, double heading, double speed) {
//   _averagePosition = ll.LatLng(0, 0);

//   if (_currentLocation == null) {
//     _updatePosition(newLocation, heading);
//     return;
//   }

//   final now = DateTime.now();
//   final timeDelta = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
//   _lastUpdateTime = now;

//   double accuracyWeight =
//       (_minAccuracy / _highAccuracyThreshold).clamp(0.1, 0.9);
//   double speedWeight = (speed / 2.0).clamp(0.1, 0.9);

//   double weight = (accuracyWeight + speedWeight) / 2.0;

//   double distance = speed * timeDelta;
//   double predictedLat = _currentLocation!.latitude +
//       distance * cos(heading * pi / 180) / 111111;
//   double predictedLng = _currentLocation!.longitude +
//       distance *
//           sin(heading * pi / 180) /
//           (111111 * cos(_currentLocation!.latitude * pi / 180));
//   ll.LatLng predictedLocation = ll.LatLng(predictedLat, predictedLng);

//   ll.LatLng smoothedLocation = ll.LatLng(
//     predictedLocation.latitude * (1 - weight) + newLocation.latitude * weight,
//     predictedLocation.longitude * (1 - weight) +
//         newLocation.longitude * weight,
//   );

//   _updatePosition(smoothedLocation, heading);
// }

// -----------------------------OLD CODE HERE -----------------//

// import 'dart:async';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter_compass/flutter_compass.dart';

// class MapBox extends StatefulWidget {
//   MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   });

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routeCoordinates = [];
//   StreamSubscription<Position>? _positionStreamSubscription;
//   List<Marker> _cornerMarkers = [];
//   bool _isTracking = false;
//   bool _isInitialized = false;
//   String? _errorMessage;
//   bool _isMapReady = false;
//   bool _isOnline = true;
//   TileProvider? _tileProvider;
//   String? _storeName;
//   ll.LatLng? _startingPosition;

//   final ll.Distance _distance = ll.Distance();

//   static const double _currentZoom = 18.0;
//   static const double _movementThreshold = 3.0; // meters
//   static const double _minAccuracy = 10.0; // meters
//   static const int _movingAverageWindow = 5;
//   static const int _maxRetries = 3;

//   List<ll.LatLng> _recentLocations = [];
//   final StreamController<double> _smoothHeadingController =
//       StreamController<double>.broadcast();
//   List<double> _headingBuffer = [];
//   static const int _headingBufferSize =
//       5; // Adjust this value for more or less smoothing

//   @override
//   void initState() {
//     super.initState();
//     _checkConnectivity();
//     _initializeLocation();
//     _initializeTileProvider();
//     _setupSmoothHeadingStream();
//   }

//   // --------------------------------------------//

//   void _toggleTracking() async {
//     if (_isTracking) {
//       _completeTracking();
//     } else {
//       await _startTracking();
//     }
//     // Update FFAppState
//     FFAppState().routeStarted = _isTracking;
//   }
//   // --------------------------------------------//

//   void _setupSmoothHeadingStream() {
//     FlutterCompass.events?.listen((event) {
//       if (event.heading != null) {
//         _headingBuffer.add(event.heading!);
//         if (_headingBuffer.length > _headingBufferSize) {
//           _headingBuffer.removeAt(0);
//         }
//         double averageHeading =
//             _headingBuffer.reduce((a, b) => a + b) / _headingBuffer.length;
//         _smoothHeadingController.add(_normalizeHeading(averageHeading));
//       }
//     });
//   }

//   double _normalizeHeading(double heading) {
//     // Ensure the heading is always between 0 and 360 degrees
//     return (heading + 360) % 360;
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     if (stores.isEmpty) {
//       print("No stores available");
//       return;
//     }

//     // Get the current location
//     Position position = await _getCurrentPositionWithRetry();
//     ll.LatLng currentLocation =
//         ll.LatLng(position.latitude, position.longitude);

//     // Find a store that contains the current location
//     for (var store in stores) {
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       if (metadata.containsKey('region_north') &&
//           metadata.containsKey('region_south') &&
//           metadata.containsKey('region_east') &&
//           metadata.containsKey('region_west')) {
//         final north = double.parse(metadata['region_north'] as String);
//         final south = double.parse(metadata['region_south'] as String);
//         final east = double.parse(metadata['region_east'] as String);
//         final west = double.parse(metadata['region_west'] as String);
//         final region = {
//           'north': north,
//           'south': south,
//           'east': east,
//           'west': west,
//         };
//         if (_isLocationInRegion(currentLocation, region)) {
//           _storeName = store.storeName;
//           break;
//         }
//       }
//     }

//     // If no matching store found, use the first store
//     if (_storeName == null && stores.isNotEmpty) {
//       _storeName = stores[0].storeName;
//     }

//     if (_storeName != null) {
//       _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//         settings: FMTC.FMTCTileProviderSettings(
//           behavior: FMTC.CacheBehavior.cacheFirst,
//         ),
//       );
//       setState(() {}); // Trigger rebuild with the new tile provider
//     } else {
//       print("No suitable store found");
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, double> region) {
//     return location.latitude >= region['south']! &&
//         location.latitude <= region['north']! &&
//         location.longitude >= region['west']! &&
//         location.longitude <= region['east']!;
//   }

//   // Initialization of current marker
//   Future<void> _initializeLocation() async {
//     try {
//       await _checkLocationPermission();
//       await _checkLocationAccuracy();

//       Position initialPosition = await _getCurrentPositionWithRetry();
//       setState(() {
//         _currentLocation =
//             ll.LatLng(initialPosition.latitude, initialPosition.longitude);
//         _isInitialized = true;
//       });

//       _startLocationStream();
//     } catch (e) {
//       setState(() {
//         _errorMessage = "Initialization error: $e";
//       });
//     }
//   }

//   Future<void> _checkConnectivity() async {
//     var connectivityResult = await (Connectivity().checkConnectivity());
//     setState(() {
//       _isOnline = connectivityResult != ConnectivityResult.none;
//     });
//   }

//   Future<void> _checkLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('Location services are disabled.');

//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Location permissions are denied');
//       }
//     }
//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Location permissions are permanently denied');
//     }
//   }

//   Future<void> _checkLocationAccuracy() async {
//     try {
//       LocationAccuracyStatus accuracy = await Geolocator.getLocationAccuracy();
//       if (accuracy == LocationAccuracyStatus.reduced) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Please enable precise location for better accuracy'),
//             action: SnackBarAction(
//               label: 'Settings',
//               onPressed: () {
//                 Geolocator.openAppSettings();
//               },
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error checking location accuracy: $e');
//     }
//   }

//   //
//   Future<Position> _getCurrentPositionWithRetry({int retries = 0}) async {
//     try {
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.best,
//         timeLimit: Duration(seconds: 10),
//       );
//     } catch (e) {
//       if (retries < _maxRetries) {
//         await Future.delayed(Duration(seconds: 2));
//         return _getCurrentPositionWithRetry(retries: retries + 1);
//       } else {
//         throw Exception(
//             'Failed to get current position after $_maxRetries attempts');
//       }
//     }
//   }

//   void _startLocationStream() {
//     LocationSettings locationSettings = LocationSettings(
//       //AndroidSettings to LocationSettings
//       accuracy: LocationAccuracy.best,
//       distanceFilter: 0,
//       // intervalDuration: const Duration(seconds: 1),
//       // forceLocationManager: true,
//       // foregroundNotificationConfig: const ForegroundNotificationConfig(
//       //   notificationText: "PCIC is tracking your location",
//       //   notificationTitle: "Location Tracking Active",
//       //   enableWakeLock: true,
//     );

//     _positionStreamSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position position) {
//         _processNewPosition(position);
//       },
//       onError: (error) {
//         print("Location stream error: $error");
//         _restartLocationStream();
//       },
//     );
//   }

//   void _restartLocationStream() {
//     _positionStreamSubscription?.cancel();
//     _startLocationStream();
//   }

//   //track new coordinates
//   void _processNewPosition(Position position) {
//     if (!_isTracking) return;
//     print('Position accuracy: ${position.accuracy} meters');
//     if (position.accuracy <= _minAccuracy) {
//       ll.LatLng newLocation = ll.LatLng(position.latitude, position.longitude);
//       _recentLocations.add(newLocation);
//       if (_recentLocations.length > _movingAverageWindow) {
//         _recentLocations.removeAt(0);
//       }
//       ll.LatLng averageLocation = _calculateAverageLocation();

//       if (_startingPosition != null) {
//         double distanceFromStart = _distance.as(
//             ll.LengthUnit.Meter, _startingPosition!, averageLocation);

//         if (distanceFromStart >= _movementThreshold ||
//             _routeCoordinates.length > 1) {
//           _updatePosition(averageLocation);
//         } else {
//           print('Not updating position: Too close to starting point');
//         }
//       } else {
//         _updatePosition(averageLocation);
//       }
//     } else {
//       print('Skipping low accuracy position');
//     }
//   }

//   void _updatePosition(ll.LatLng location) {
//     setState(() {
//       _currentLocation = location;
//       if (_isTracking) {
//         _routeCoordinates.add(_currentLocation!);
//       }
//       if (_isMapReady) {
//         _mapController.move(_currentLocation!, _currentZoom);
//       }
//     });
//   }

//   ll.LatLng _calculateAverageLocation() {
//     double latSum = 0, lonSum = 0;
//     for (var loc in _recentLocations) {
//       latSum += loc.latitude;
//       lonSum += loc.longitude;
//     }
//     return ll.LatLng(
//         latSum / _recentLocations.length, lonSum / _recentLocations.length);
//   }

//   Future<bool> _isGpsEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }

//   Future<void> _startTracking() async {
//     if (_isInitialized && !_isTracking) {
//       bool gpsEnabled = await _isGpsEnabled();
//       if (!gpsEnabled) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content:
//               Text('GPS is not enabled. Please turn on GPS to start tracking.'),
//         ));
//         FFAppState().routeStarted = false;
//         return;
//       }

//       try {
//         setState(() {
//           _isTracking = true;
//           _routeCoordinates.clear();
//           _cornerMarkers.clear();
//           _startingPosition = _currentLocation;
//         });

//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return AlertDialog(
//                 title: Text('Initializing GPS'),
//                 content: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 20),
//                     Text('Please wait for 10 seconds while GPS stabilizes...'),
//                   ],
//                 ),
//               );
//             },
//           );
//         });

//         await Future.delayed(Duration(seconds: 10));

//         Position startPosition = await _getCurrentPositionWithRetry();

//         setState(() {
//           _startingPosition =
//               ll.LatLng(startPosition.latitude, startPosition.longitude);
//           _routeCoordinates.add(_startingPosition!);
//           _cornerMarkers.add(
//             Marker(
//               point: _startingPosition!,
//               child: Icon(Icons.star, color: Colors.red),
//             ),
//           );
//         });

//         Navigator.of(context).pop(); // Dismiss the dialog

//         // Start updating positions
//         _startLocationStream();

//         FFAppState().routeStarted = true;
//       } catch (e) {
//         setState(() {
//           _isTracking = false;
//           _errorMessage = "Failed to start tracking: $e";
//         });
//         FFAppState().routeStarted = false;
//       }
//     }
//   }

//   void _completeTracking() {
//     if (_isTracking) {
//       setState(() {
//         _isTracking = false;
//         if (_routeCoordinates.isNotEmpty &&
//             _routeCoordinates.first != _routeCoordinates.last) {
//           _routeCoordinates.add(_routeCoordinates.first);
//         }
//       });

//       // Convert ll.LatLng to FlutterFlow's LatLng
//       List<LatLng> convertedCoordinates = _routeCoordinates
//           .map((coord) => LatLng(coord.latitude, coord.longitude))
//           .toList();

//       debugPrint('Converted coordinates: $convertedCoordinates');
//       // debugPrint('Task ID: ${FFAppState().currentTaskId}');
//       debugPrint('Saving IDK');

//       /// saveGpx('idk', convertedCoordinates);
//       saveGpx(widget.taskId ?? 'default_task_id', convertedCoordinates);
//     }
//   }

//   void recenterMap() {
//     if (_currentLocation != null && _isMapReady) {
//       _mapController.move(_currentLocation!, _currentZoom);
//     }
//   }

//   @override
//   void dispose() {
//     _smoothHeadingController.close();
//     _positionStreamSubscription?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = FFAppState();

//     if (appState.routeStarted && !_isTracking) {
//       _startTracking();
//     } else if (!appState.routeStarted && _isTracking) {
//       _completeTracking();
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('Error: $_errorMessage'),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _errorMessage = null;
//                   _isInitialized = false;
//                 });
//                 _initializeLocation();
//               },
//               child: Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (!_isInitialized || _currentLocation == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Stack(
//       children: [
//         SizedBox(
//           width: widget.width ?? MediaQuery.of(context).size.width,
//           height: widget.height ?? MediaQuery.of(context).size.height,
//           child: FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _currentLocation!,
//               initialZoom: _currentZoom,
//               minZoom: 16,
//               maxZoom: 22,
//               onMapReady: () {
//                 setState(() {
//                   _isMapReady = true;
//                 });
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate:
//                     'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//                 additionalOptions: {
//                   'accessToken': widget.accessToken ?? '',
//                 },
//                 tileProvider: _tileProvider,
//               ),
//               CurrentLocationLayer(
//                 alignPositionOnUpdate: AlignOnUpdate.always,
//                 alignDirectionOnUpdate: AlignOnUpdate.never,
//                 alignDirectionStream: _smoothHeadingController.stream,
//                 style: LocationMarkerStyle(
//                   marker: const DefaultLocationMarker(color: Colors.green),
//                   markerSize: const Size(
//                       15, 15), // Slightly larger for better visibility
//                   markerDirection: MarkerDirection.heading,
//                   accuracyCircleColor: Colors.green.withOpacity(0.2),
//                   headingSectorColor: Colors.green.withOpacity(0.8),
//                 ),
//                 alignDirectionAnimationDuration: Duration(
//                     milliseconds: 200), // Slightly slower for smoother rotation
//               ),
//               if (_isTracking)
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routeCoordinates,
//                       strokeWidth: 4.0,
//                       color: Colors.blue,
//                     ),
//                   ],
//                 ),
//               if (!_isTracking && _routeCoordinates.isNotEmpty)
//                 PolygonLayer(
//                   polygons: [
//                     Polygon(
//                       points: _routeCoordinates,
//                       color: Colors.blue.withOpacity(0.2),
//                       borderColor: Colors.blue,
//                       borderStrokeWidth: 3,
//                     ),
//                   ],
//                 ),
//               MarkerLayer(markers: _cornerMarkers),
//             ],
//           ),
//         ),
//         Positioned(
//           top: 50,
//           right: 20,
//           child: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Color(0x7f0f1113),
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.transparent, width: 1),
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(30),
//                 onTap: recenterMap,
//                 child: Center(
//                   child: Icon(
//                     Icons.my_location_outlined,
//                     color: Colors.white,
//                     size: 24,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         Positioned(
//           bottom: 20,
//           right: 20,
//           child: FloatingActionButton(
//             onPressed: _toggleTracking,
//             child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
//           ),
//         ),
//       ],
//     );
//   }
// }

// //The unknown well yeeeeeeeett
// import 'dart:async';
// import 'dart:math';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:connectivity_plus/connectivity_plus.dart';

// class MapBox extends StatefulWidget {
//   const MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   }) : super(key: key);

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   StreamSubscription<Position>? _positionStreamSubscription;

//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routeCoordinates = [];
//   ll.LatLng? _startingPosition;
//   final ll.Distance _distance = ll.Distance();

//   bool _isTracking = false;
//   bool _isMapReady = false;

//   TileProvider? _tileProvider;
//   String? _storeName;

//   String? _errorMessage;

//   static const double _currentZoom = 19.0;
//   static const int _positionStreamIntervalMs = 100;
//   static const int _initialPositionSamples = 50;
//   static const double _highAccuracyThreshold = 10.0;
//   static const double _stationarySpeedThreshold = 0.1;
//   static const double _significantMovementThreshold = 0.5;
//   static const int _stationaryWindowSize = 20;

//   late SimpleKalmanFilter _latFilter;
//   late SimpleKalmanFilter _lonFilter;

//   List<Position> _recentPositions = [];

//   ll.LatLng _averagePosition = ll.LatLng(0, 0);
//   bool _isStationary = true;

//   DateTime _lastUpdateTime = DateTime.now();
//   double? _currentHeading;
//   ll.LatLng? _lastFilteredLocation;

//   @override
//   void initState() {
//     super.initState();
//     _latFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _lonFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _checkConnectivity();
//     _initializeTileProvider();
//     _initializeLocation();
//   }

//   Future<void> _checkConnectivity() async {
//     var connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       setState(() {
//         _errorMessage = "No internet connection.";
//       });
//     }
//   }

//   Future<void> _initializeLocation() async {
//     try {
//       await _checkLocationPermission();
//       await _checkLocationAccuracy();

//       Position initialPosition = await _getAccuratePosition();

//       if (!mounted) return;

//       setState(() {
//         _currentLocation =
//             ll.LatLng(initialPosition.latitude, initialPosition.longitude);
//         _routeCoordinates.add(_currentLocation!);
//         if (_isMapReady) {
//           _mapController.move(_currentLocation!, _currentZoom);
//         }
//       });

//       _startLocationStream();
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "Initialization error: $e";
//         });
//       }
//     }
//   }

//   Future<Position> _getAccuratePosition() async {
//     List<Position> samples = [];
//     for (int i = 0; i < _initialPositionSamples; i++) {
//       Position position = await _getCurrentPositionWithRetry();
//       samples.add(position);
//       await Future.delayed(Duration(milliseconds: 200));
//     }

//     double sumLat = 0, sumLon = 0, sumAcc = 0;
//     for (var pos in samples) {
//       sumLat += pos.latitude;
//       sumLon += pos.longitude;
//       sumAcc += pos.accuracy;
//     }

//     double avgLat = sumLat / _initialPositionSamples;
//     double avgLon = sumLon / _initialPositionSamples;
//     double avgAcc = sumAcc / _initialPositionSamples;

//     _latFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01
//     _lonFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01

//     return Position(
//       latitude: avgLat,
//       longitude: avgLon,
//       timestamp: DateTime.now(),
//       accuracy: avgAcc,
//       altitude: samples.last.altitude,
//       heading: samples.last.heading,
//       speed: samples.last.speed,
//       speedAccuracy: samples.last.speedAccuracy,
//       altitudeAccuracy: samples.last.altitudeAccuracy ?? 0,
//       headingAccuracy: samples.last.headingAccuracy ?? 0,
//     );
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     if (stores.isEmpty) {
//       print("No stores available");
//       return;
//     }

//     Position position = await _getCurrentPositionWithRetry();
//     if (!mounted) return;
//     ll.LatLng currentLocation =
//         ll.LatLng(position.latitude, position.longitude);

//     for (var store in stores) {
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       if (metadata != null && _isLocationInRegion(currentLocation, metadata)) {
//         _storeName = store.storeName;
//         break;
//       }
//     }

//     _storeName ??= stores.isNotEmpty ? stores[0].storeName : null;

//     if (_storeName != null) {
//       setState(() {
//         _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//           settings: FMTC.FMTCTileProviderSettings(
//             behavior: FMTC.CacheBehavior.cacheFirst,
//           ),
//         );
//       });
//     } else {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "No suitable tile store found.";
//         });
//       }
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, dynamic> region) {
//     return location.latitude >= region['region_south'] &&
//         location.latitude <= region['region_north'] &&
//         location.longitude >= region['region_west'] &&
//         location.longitude <= region['region_east'];
//   }

//   Future<void> _checkLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('Location services are disabled.');

//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Location permissions are denied');
//       }
//     }
//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Location permissions are permanently denied');
//     }
//   }

//   Future<void> _checkLocationAccuracy() async {
//     try {
//       LocationAccuracyStatus accuracy = await Geolocator.getLocationAccuracy();
//       if (accuracy == LocationAccuracyStatus.reduced && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Please enable precise location for better accuracy'),
//             action: SnackBarAction(
//               label: 'Settings',
//               onPressed: () {
//                 Geolocator.openAppSettings();
//               },
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error checking location accuracy: $e');
//     }
//   }

//   Future<Position> _getCurrentPositionWithRetry({int retries = 0}) async {
//     try {
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.best,
//         timeLimit: Duration(seconds: 10),
//       );
//     } catch (e) {
//       if (retries < 3) {
//         await Future.delayed(Duration(seconds: 2));
//         return _getCurrentPositionWithRetry(retries: retries + 1);
//       } else {
//         _showSnackbar("Failed to get accurate location, using best effort.");
//         return await Geolocator.getLastKnownPosition() ??
//             Position(
//               longitude: 0.0,
//               latitude: 0.0,
//               timestamp: DateTime.now(),
//               accuracy: 0.0,
//               altitude: 0.0,
//               heading: 0.0,
//               speed: 0.0,
//               speedAccuracy: 0.0,
//               altitudeAccuracy: 0.0,
//               headingAccuracy: 0.0,
//             );
//       }
//     }
//   }

//   Future<bool> _isGpsEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }

//   void _startLocationStream() {
//     final LocationSettings locationSettings = AndroidSettings(
//       accuracy: LocationAccuracy.bestForNavigation,
//       distanceFilter: 1,
//       forceLocationManager: false,
//       intervalDuration: Duration(milliseconds: _positionStreamIntervalMs),
//     );

//     _positionStreamSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position position) {
//         if (mounted) {
//           _processNewPosition(position);
//         }
//       },
//       onError: (error) {
//         print("Location stream error: $error");
//         _restartLocationStream();
//       },
//     );
//   }

//   void _restartLocationStream() {
//     _positionStreamSubscription?.cancel();
//     Future.delayed(Duration(seconds: 1), _startLocationStream);
//   }

//   void _processNewPosition(Position position) {
//     // Apply Kalman filter for the marker position
//     double filteredLat = _latFilter.filter(position.latitude);
//     double filteredLon = _lonFilter.filter(position.longitude);
//     ll.LatLng filteredLocation = ll.LatLng(filteredLat, filteredLon);

//     // Use raw coordinates for the route
//     ll.LatLng rawLocation = ll.LatLng(position.latitude, position.longitude);

//     _updatePosition(
//         filteredLocation, rawLocation, position.heading, position.speed);
//   }

//   void _updatePosition(ll.LatLng filteredLocation, ll.LatLng rawLocation,
//       double heading, double speed) {
//     setState(() {
//       _currentLocation =
//           filteredLocation; // Use filtered location for the marker
//       _currentHeading = heading;
//       _lastFilteredLocation = filteredLocation;
//       _lastUpdateTime = DateTime.now();

//       if (_isMapReady && _shouldRecenterMap()) {
//         _mapController.move(_currentLocation!, _currentZoom);
//         if (speed > _stationarySpeedThreshold) {
//           _mapController.rotate(heading);
//         }
//       }

//       if (_isTracking) {
//         _addToRoute(rawLocation); // Use raw location for the route
//       }
//     });
//   }

//   void _addToRoute(ll.LatLng newLocation) {
//     // Always add the new raw location to make the route more detailed
//     setState(() {
//       _routeCoordinates.add(newLocation);
//     });
//   }

//   Future<void> _startTracking() async {
//     if (_currentLocation != null && !_isTracking) {
//       bool gpsEnabled = await _isGpsEnabled();
//       if (!gpsEnabled) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text(
//                 'GPS is not enabled. Please turn on GPS to start tracking.'),
//           ));
//         }
//         FFAppState().routeStarted = false;
//         return;
//       }

//       try {
//         setState(() {
//           _isTracking = true;
//           _routeCoordinates.clear();
//           _startingPosition = _currentLocation;
//         });

//         Position startPosition = await _getAccuratePosition();
//         if (!mounted) return;

//         setState(() {
//           _startingPosition =
//               ll.LatLng(startPosition.latitude, startPosition.longitude);
//           _routeCoordinates.add(_startingPosition!);
//         });

//         FFAppState().routeStarted = true;
//       } catch (e) {
//         if (mounted) {
//           setState(() {
//             _isTracking = false;
//             _errorMessage = "Failed to start tracking: $e";
//           });
//         }
//         FFAppState().routeStarted = false;
//       }
//     }
//   }

//   void _completeTracking() {
//     if (_isTracking) {
//       setState(() {
//         _isTracking = false;
//         if (_routeCoordinates.isNotEmpty &&
//             _routeCoordinates.first != _routeCoordinates.last) {
//           _routeCoordinates.add(_routeCoordinates.first);
//         }
//       });

//       List<LatLng> convertedCoordinates = _routeCoordinates
//           .map((coord) => LatLng(coord.latitude, coord.longitude))
//           .toList();

//       debugPrint('Converted coordinates: $convertedCoordinates');
//       saveGpx(widget.taskId ?? 'default_task_id', convertedCoordinates);

//       FFAppState().routeStarted = false;
//     }
//   }

//   void _recenterMap() {
//     if (_currentLocation != null && _isMapReady) {
//       _mapController.move(_currentLocation!, _currentZoom);
//     }
//   }

//   bool _shouldRecenterMap() {
//     if (!_isMapReady || _currentLocation == null) return false;

//     final mapBounds = LatLngBounds.fromPoints(
//       [
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, -1, -1),
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, 1, 1),
//       ],
//     );

//     final currentPoint =
//         _mapController.camera.latLngToScreenPoint(_currentLocation!);

//     return currentPoint == null || !mapBounds.contains(_currentLocation!);
//   }

//   ll.LatLng _calculateOffset(
//       ll.LatLng center, double zoom, double xOffset, double yOffset) {
//     final double scaleFactor = 0.01 / zoom;
//     return ll.LatLng(
//       center.latitude + (scaleFactor * yOffset),
//       center.longitude + (scaleFactor * xOffset),
//     );
//   }

//   void _showSnackbar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = FFAppState();

//     if (appState.routeStarted && !_isTracking) {
//       _startTracking();
//     }

//     if (!appState.routeStarted && _isTracking) {
//       _completeTracking();
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('Error: $_errorMessage'),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _errorMessage = null;
//                 });
//                 _initializeLocation();
//               },
//               child: Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (_currentLocation == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Stack(
//       children: [
//         SizedBox(
//           width: widget.width ?? MediaQuery.of(context).size.width,
//           height: widget.height ?? MediaQuery.of(context).size.height,
//           child: FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _currentLocation!,
//               initialZoom: _currentZoom,
//               minZoom: 18,
//               maxZoom: 22,
//               onMapReady: () {
//                 setState(() {
//                   _isMapReady = true;
//                   if (_currentLocation != null) {
//                     _mapController.move(_currentLocation!, _currentZoom);
//                   }
//                 });
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate:
//                     'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//                 additionalOptions: {
//                   'accessToken': widget.accessToken ?? '',
//                 },
//                 tileProvider: _tileProvider,
//               ),
//               CurrentLocationLayer(
//                 followOnLocationUpdate: FollowOnLocationUpdate.always,
//                 style: LocationMarkerStyle(
//                   marker: const DefaultLocationMarker(color: Colors.green),
//                   markerSize: const Size(12, 12),
//                   markerDirection: MarkerDirection.heading,
//                   accuracyCircleColor: Colors.green.withOpacity(0.2),
//                   headingSectorColor: Colors.green.withOpacity(0.8),
//                   headingSectorRadius: 60,
//                 ),
//                 moveAnimationDuration: Duration.zero,
//               ),
//               if (_routeCoordinates.isNotEmpty &&
//                   (appState.routeStarted || _isTracking))
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routeCoordinates,
//                       strokeWidth: 3.0,
//                       color: Colors.blue,
//                     ),
//                   ],
//                 ),
//               MarkerLayer(
//                 markers: _startingPosition != null
//                     ? [
//                         Marker(
//                           point: _startingPosition!,
//                           child: Icon(
//                             Icons.pin_drop,
//                             color: Colors.red,
//                             size: 10.0,
//                           ),
//                         ),
//                       ]
//                     : [],
//               ),
//             ],
//           ),
//         ),
//         Positioned(
//           top: 50,
//           right: 20,
//           child: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Color(0x7f0f1113),
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.transparent, width: 1),
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(30),
//                 onTap: _recenterMap,
//                 child: Center(
//                   child: Icon(
//                     Icons.my_location_outlined,
//                     color: Colors.white,
//                     size: 24,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class SimpleKalmanFilter {
//   double _e;
//   double _q;
//   double? _lastEstimate;

//   SimpleKalmanFilter({required double e, required double q})
//       : _e = e,
//         _q = q;

//   double filter(double measurement) {
//     if (_lastEstimate == null) {
//       _lastEstimate = measurement;
//       return measurement;
//     }

//     double prediction = _lastEstimate!;
//     double kalmanGain = _e / (_e + _q);
//     double estimate = prediction + kalmanGain * (measurement - prediction);

//     _e = (1 - kalmanGain) * _e + ((_lastEstimate! - estimate).abs()) * _q;
//     _lastEstimate = estimate;

//     return estimate;
//   }
// }

// import 'dart:async';
// import 'dart:math';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:connectivity_plus/connectivity_plus.dart';

// class MapBox extends StatefulWidget {
//   const MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   }) : super(key: key);

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   StreamSubscription<Position>? _positionStreamSubscription;

//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routeCoordinates = [];
//   ll.LatLng? _startingPosition;
//   final ll.Distance _distance = ll.Distance();

//   bool _isTracking = false;
//   bool _isMapReady = false;

//   TileProvider? _tileProvider;
//   String? _storeName;

//   String? _errorMessage;

//   static const double _currentZoom = 19.0;
//   static const int _positionStreamIntervalMs = 100;
//   static const int _initialPositionSamples = 20;
//   static const double _highAccuracyThreshold = 10.0;
//   static const double _stationarySpeedThreshold = 0.1;
//   static const double _significantMovementThreshold = 0.5;
//   static const int _stationaryWindowSize = 20;

//   late SimpleKalmanFilter _latFilter;
//   late SimpleKalmanFilter _lonFilter;

//   List<Position> _recentPositions = [];

//   ll.LatLng _averagePosition = ll.LatLng(0, 0);
//   bool _isStationary = true;

//   DateTime _lastUpdateTime = DateTime.now();
//   double? _currentHeading;
//   ll.LatLng? _lastFilteredLocation;

//   @override
//   void initState() {
//     super.initState();
//     _latFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _lonFilter =
//         SimpleKalmanFilter(e: 3, q: 0.02); // Decreased q from 0.5 to 0.02
//     _checkConnectivity();
//     _initializeTileProvider();
//     _initializeLocation();
//   }

//   Future<void> _checkConnectivity() async {
//     var connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       setState(() {
//         _errorMessage = "No internet connection.";
//       });
//     }
//   }

//   Future<void> _initializeLocation() async {
//     try {
//       await _checkLocationPermission();
//       await _checkLocationAccuracy();

//       Position initialPosition = await _getAccuratePosition();

//       if (!mounted) return;

//       setState(() {
//         _currentLocation =
//             ll.LatLng(initialPosition.latitude, initialPosition.longitude);
//         _routeCoordinates.add(_currentLocation!);
//         if (_isMapReady) {
//           _mapController.move(_currentLocation!, _currentZoom);
//         }
//       });

//       _startLocationStream();
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "Initialization error: $e";
//         });
//       }
//     }
//   }

//   Future<Position> _getAccuratePosition() async {
//     List<Position> samples = [];
//     for (int i = 0; i < _initialPositionSamples; i++) {
//       Position position = await _getCurrentPositionWithRetry();
//       samples.add(position);
//       await Future.delayed(Duration(milliseconds: 200));
//     }

//     double sumLat = 0, sumLon = 0, sumAcc = 0;
//     for (var pos in samples) {
//       sumLat += pos.latitude;
//       sumLon += pos.longitude;
//       sumAcc += pos.accuracy;
//     }

//     double avgLat = sumLat / _initialPositionSamples;
//     double avgLon = sumLon / _initialPositionSamples;
//     double avgAcc = sumAcc / _initialPositionSamples;

//     _latFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01
//     _lonFilter = SimpleKalmanFilter(
//         e: avgAcc, q: 0.01); // Increased q from 0.001 to 0.01

//     return Position(
//       latitude: avgLat,
//       longitude: avgLon,
//       timestamp: DateTime.now(),
//       accuracy: avgAcc,
//       altitude: samples.last.altitude,
//       heading: samples.last.heading,
//       speed: samples.last.speed,
//       speedAccuracy: samples.last.speedAccuracy,
//       altitudeAccuracy: samples.last.altitudeAccuracy ?? 0,
//       headingAccuracy: samples.last.headingAccuracy ?? 0,
//     );
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     if (stores.isEmpty) {
//       print("No stores available");
//       return;
//     }

//     Position position = await _getCurrentPositionWithRetry();
//     if (!mounted) return;
//     ll.LatLng currentLocation =
//         ll.LatLng(position.latitude, position.longitude);

//     for (var store in stores) {
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       if (metadata != null && _isLocationInRegion(currentLocation, metadata)) {
//         _storeName = store.storeName;
//         break;
//       }
//     }

//     _storeName ??= stores.isNotEmpty ? stores[0].storeName : null;

//     if (_storeName != null) {
//       setState(() {
//         _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//           settings: FMTC.FMTCTileProviderSettings(
//             behavior: FMTC.CacheBehavior.cacheFirst,
//           ),
//         );
//       });
//     } else {
//       if (mounted) {
//         setState(() {
//           _errorMessage = "No suitable tile store found.";
//         });
//       }
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, dynamic> region) {
//     return location.latitude >= region['region_south'] &&
//         location.latitude <= region['region_north'] &&
//         location.longitude >= region['region_west'] &&
//         location.longitude <= region['region_east'];
//   }

//   Future<void> _checkLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('Location services are disabled.');

//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Location permissions are denied');
//       }
//     }
//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Location permissions are permanently denied');
//     }
//   }

//   Future<void> _checkLocationAccuracy() async {
//     try {
//       LocationAccuracyStatus accuracy = await Geolocator.getLocationAccuracy();
//       if (accuracy == LocationAccuracyStatus.reduced && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Please enable precise location for better accuracy'),
//             action: SnackBarAction(
//               label: 'Settings',
//               onPressed: () {
//                 Geolocator.openAppSettings();
//               },
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error checking location accuracy: $e');
//     }
//   }

//   Future<Position> _getCurrentPositionWithRetry({int retries = 0}) async {
//     try {
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.best,
//         timeLimit: Duration(seconds: 10),
//       );
//     } catch (e) {
//       if (retries < 3) {
//         await Future.delayed(Duration(seconds: 2));
//         return _getCurrentPositionWithRetry(retries: retries + 1);
//       } else {
//         _showSnackbar("Failed to get accurate location, using best effort.");
//         return await Geolocator.getLastKnownPosition() ??
//             Position(
//               longitude: 0.0,
//               latitude: 0.0,
//               timestamp: DateTime.now(),
//               accuracy: 0.0,
//               altitude: 0.0,
//               heading: 0.0,
//               speed: 0.0,
//               speedAccuracy: 0.0,
//               altitudeAccuracy: 0.0,
//               headingAccuracy: 0.0,
//             );
//       }
//     }
//   }

//   Future<bool> _isGpsEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }

//   void _startLocationStream() {
//     final LocationSettings locationSettings = AndroidSettings(
//       accuracy: LocationAccuracy.bestForNavigation,
//       distanceFilter: 1,
//       forceLocationManager: false,
//       intervalDuration: Duration(milliseconds: _positionStreamIntervalMs),
//     );

//     _positionStreamSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position position) {
//         if (mounted) {
//           _processNewPosition(position);
//         }
//       },
//       onError: (error) {
//         print("Location stream error: $error");
//         _restartLocationStream();
//       },
//     );
//   }

//   void _restartLocationStream() {
//     _positionStreamSubscription?.cancel();
//     Future.delayed(Duration(seconds: 1), _startLocationStream);
//   }

//   void _processNewPosition(Position position) {
//     // Apply Kalman filter for the marker position
//     double filteredLat = _latFilter.filter(position.latitude);
//     double filteredLon = _lonFilter.filter(position.longitude);
//     ll.LatLng filteredLocation = ll.LatLng(filteredLat, filteredLon);

//     // Use raw coordinates for the route
//     ll.LatLng rawLocation = ll.LatLng(position.latitude, position.longitude);

//     _updatePosition(
//         filteredLocation, rawLocation, position.heading, position.speed);
//   }

//   void _updatePosition(ll.LatLng filteredLocation, ll.LatLng rawLocation,
//       double heading, double speed) {
//     setState(() {
//       _currentLocation =
//           filteredLocation; // Use filtered location for the marker
//       _currentHeading = heading;
//       _lastFilteredLocation = filteredLocation;
//       _lastUpdateTime = DateTime.now();

//       if (_isMapReady && _shouldRecenterMap()) {
//         _mapController.move(_currentLocation!, _currentZoom);
//         if (speed > _stationarySpeedThreshold) {
//           _mapController.rotate(heading);
//         }
//       }

//       if (_isTracking) {
//         _addToRoute(rawLocation); // Use raw location for the route
//       }
//     });
//   }

//   void _addToRoute(ll.LatLng newLocation) {
//     // Always add the new raw location to make the route more detailed
//     setState(() {
//       _routeCoordinates.add(newLocation);
//     });
//   }

//   Future<void> _startTracking() async {
//     if (_currentLocation != null && !_isTracking) {
//       bool gpsEnabled = await _isGpsEnabled();
//       if (!gpsEnabled) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text(
//                 'GPS is not enabled. Please turn on GPS to start tracking.'),
//           ));
//         }
//         FFAppState().routeStarted = false;
//         return;
//       }

//       try {
//         setState(() {
//           _isTracking = true;
//           _routeCoordinates.clear();
//           _startingPosition = _currentLocation;
//         });

//         Position startPosition = await _getAccuratePosition();
//         if (!mounted) return;

//         setState(() {
//           _startingPosition =
//               ll.LatLng(startPosition.latitude, startPosition.longitude);
//           _routeCoordinates.add(_startingPosition!);
//         });

//         FFAppState().routeStarted = true;
//       } catch (e) {
//         if (mounted) {
//           setState(() {
//             _isTracking = false;
//             _errorMessage = "Failed to start tracking: $e";
//           });
//         }
//         FFAppState().routeStarted = false;
//       }
//     }
//   }

//   void _completeTracking() {
//     if (_isTracking) {
//       setState(() {
//         _isTracking = false;
//         if (_routeCoordinates.isNotEmpty &&
//             _routeCoordinates.first != _routeCoordinates.last) {
//           _routeCoordinates.add(_routeCoordinates.first);
//         }
//       });

//       List<LatLng> convertedCoordinates = _routeCoordinates
//           .map((coord) => LatLng(coord.latitude, coord.longitude))
//           .toList();

//       debugPrint('Converted coordinates: $convertedCoordinates');
//       saveGpx(widget.taskId ?? 'default_task_id', convertedCoordinates);

//       FFAppState().routeStarted = false;
//     }
//   }

//   void _recenterMap() {
//     if (_currentLocation != null && _isMapReady) {
//       _mapController.move(_currentLocation!, _currentZoom);
//     }
//   }

//   bool _shouldRecenterMap() {
//     if (!_isMapReady || _currentLocation == null) return false;

//     final mapBounds = LatLngBounds.fromPoints(
//       [
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, -1, -1),
//         _calculateOffset(_currentLocation!, _mapController.camera.zoom, 1, 1),
//       ],
//     );

//     final currentPoint =
//         _mapController.camera.latLngToScreenPoint(_currentLocation!);

//     return currentPoint == null || !mapBounds.contains(_currentLocation!);
//   }

//   ll.LatLng _calculateOffset(
//       ll.LatLng center, double zoom, double xOffset, double yOffset) {
//     final double scaleFactor = 0.01 / zoom;
//     return ll.LatLng(
//       center.latitude + (scaleFactor * yOffset),
//       center.longitude + (scaleFactor * xOffset),
//     );
//   }

//   void _showSnackbar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = FFAppState();

//     if (appState.routeStarted && !_isTracking) {
//       _startTracking();
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('Error: $_errorMessage'),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _errorMessage = null;
//                 });
//                 _initializeLocation();
//               },
//               child: Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (_currentLocation == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Stack(
//       children: [
//         SizedBox(
//           width: widget.width ?? MediaQuery.of(context).size.width,
//           height: widget.height ?? MediaQuery.of(context).size.height,
//           child: FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _currentLocation!,
//               initialZoom: _currentZoom,
//               minZoom: 18,
//               maxZoom: 22,
//               onMapReady: () {
//                 setState(() {
//                   _isMapReady = true;
//                   if (_currentLocation != null) {
//                     _mapController.move(_currentLocation!, _currentZoom);
//                   }
//                 });
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate:
//                     'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//                 additionalOptions: {
//                   'accessToken': widget.accessToken ?? '',
//                 },
//                 tileProvider: _tileProvider,
//               ),
//               CurrentLocationLayer(
//                 followOnLocationUpdate: FollowOnLocationUpdate.always,
//                 style: LocationMarkerStyle(
//                   marker: const DefaultLocationMarker(color: Colors.green),
//                   markerSize: const Size(12, 12),
//                   markerDirection: MarkerDirection.heading,
//                   accuracyCircleColor: Colors.green.withOpacity(0.2),
//                   headingSectorColor: Colors.green.withOpacity(0.8),
//                   headingSectorRadius: 60,
//                 ),
//                 moveAnimationDuration: Duration.zero,
//               ),
//               if (_routeCoordinates.isNotEmpty &&
//                   (appState.routeStarted || _isTracking))
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routeCoordinates,
//                       strokeWidth: 4.0,
//                       color: Colors.blue,
//                     ),
//                   ],
//                 ),
//               MarkerLayer(
//                 markers: _startingPosition != null
//                     ? [
//                         Marker(
//                           point: _startingPosition!,
//                           child: Icon(Icons.star, color: Colors.red),
//                         ),
//                       ]
//                     : [],
//               ),
//             ],
//           ),
//         ),
//         Positioned(
//           top: 50,
//           right: 20,
//           child: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Color(0x7f0f1113),
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.transparent, width: 1),
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(30),
//                 onTap: _recenterMap,
//                 child: Center(
//                   child: Icon(
//                     Icons.my_location_outlined,
//                     color: Colors.white,
//                     size: 24,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class SimpleKalmanFilter {
//   double _e;
//   double _q;
//   double? _lastEstimate;

//   SimpleKalmanFilter({required double e, required double q})
//       : _e = e,
//         _q = q;

//   double filter(double measurement) {
//     if (_lastEstimate == null) {
//       _lastEstimate = measurement;
//       return measurement;
//     }

//     double prediction = _lastEstimate!;
//     double kalmanGain = _e / (_e + _q);
//     double estimate = prediction + kalmanGain * (measurement - prediction);

//     _e = (1 - kalmanGain) * _e + ((_lastEstimate! - estimate).abs()) * _q;
//     _lastEstimate = estimate;

//     return estimate;
//   }
// }
// -----------------------------FOR BACK UP -------------------------------//

// void _processNewPosition(Position position) {
//   print('Current position accuracy: ${position.accuracy} meters');
//   if (position.accuracy > _highAccuracyThreshold) {
//     return;
//   }

//   double filteredLat = _latitudeFilter!.update(position.latitude);
//   double filteredLon = _longitudeFilter!.update(position.longitude);
//   ll.LatLng newLocation = ll.LatLng(filteredLat, filteredLon);

//   _recentPositions.add(position);
//   if (_recentPositions.length > _stationaryWindowSize) {
//     _recentPositions.removeAt(0);
//   }

//   _isStationary = _checkIfStationary();

//   if (_isStationary) {
//     _updatePositionStationary(newLocation);
//   } else {
//     _updatePositionMoving(newLocation, position.heading, position.speed);
//   }

//   if (_isTracking || FFAppState().routeStarted) {
//     _addToRoute(newLocation);
//   }
// }

// void _updatePosition(ll.LatLng location, double heading) {
//   setState(() {
//     _currentLocation = location;
//     _currentHeading = heading;
//     if (_isMapReady && _shouldRecenterMap()) {
//       _mapController.move(_currentLocation!, _currentZoom);
//       if (!_isStationary) {
//         _mapController.rotate(heading);
//       }
//     }
//   });
// }

// void _updatePositionMoving(
//     ll.LatLng newLocation, double heading, double speed) {
//   _averagePosition = ll.LatLng(0, 0);

//   if (_currentLocation == null) {
//     _updatePosition(newLocation, heading);
//     return;
//   }

//   final now = DateTime.now();
//   final timeDelta = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
//   _lastUpdateTime = now;

//   double accuracyWeight =
//       (_minAccuracy / _highAccuracyThreshold).clamp(0.1, 0.9);
//   double speedWeight = (speed / 2.0).clamp(0.1, 0.9);

//   double weight = (accuracyWeight + speedWeight) / 2.0;

//   double distance = speed * timeDelta;
//   double predictedLat = _currentLocation!.latitude +
//       distance * cos(heading * pi / 180) / 111111;
//   double predictedLng = _currentLocation!.longitude +
//       distance *
//           sin(heading * pi / 180) /
//           (111111 * cos(_currentLocation!.latitude * pi / 180));
//   ll.LatLng predictedLocation = ll.LatLng(predictedLat, predictedLng);

//   ll.LatLng smoothedLocation = ll.LatLng(
//     predictedLocation.latitude * (1 - weight) + newLocation.latitude * weight,
//     predictedLocation.longitude * (1 - weight) +
//         newLocation.longitude * weight,
//   );

//   _updatePosition(smoothedLocation, heading);
// }

// -----------------------------OLD CODE HERE -----------------//

// import 'dart:async';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' as ll;
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter_compass/flutter_compass.dart';

// class MapBox extends StatefulWidget {
//   MapBox({
//     Key? key,
//     this.width,
//     this.height,
//     this.accessToken,
//     this.taskId,
//   });

//   final double? width;
//   final double? height;
//   final String? accessToken;
//   final String? taskId;

//   @override
//   State<MapBox> createState() => _MapBoxState();
// }

// class _MapBoxState extends State<MapBox> {
//   final MapController _mapController = MapController();
//   ll.LatLng? _currentLocation;
//   List<ll.LatLng> _routeCoordinates = [];
//   StreamSubscription<Position>? _positionStreamSubscription;
//   List<Marker> _cornerMarkers = [];
//   bool _isTracking = false;
//   bool _isInitialized = false;
//   String? _errorMessage;
//   bool _isMapReady = false;
//   bool _isOnline = true;
//   TileProvider? _tileProvider;
//   String? _storeName;
//   ll.LatLng? _startingPosition;

//   final ll.Distance _distance = ll.Distance();

//   static const double _currentZoom = 18.0;
//   static const double _movementThreshold = 3.0; // meters
//   static const double _minAccuracy = 10.0; // meters
//   static const int _movingAverageWindow = 5;
//   static const int _maxRetries = 3;

//   List<ll.LatLng> _recentLocations = [];
//   final StreamController<double> _smoothHeadingController =
//       StreamController<double>.broadcast();
//   List<double> _headingBuffer = [];
//   static const int _headingBufferSize =
//       5; // Adjust this value for more or less smoothing

//   @override
//   void initState() {
//     super.initState();
//     _checkConnectivity();
//     _initializeLocation();
//     _initializeTileProvider();
//     _setupSmoothHeadingStream();
//   }

//   // --------------------------------------------//

//   void _toggleTracking() async {
//     if (_isTracking) {
//       _completeTracking();
//     } else {
//       await _startTracking();
//     }
//     // Update FFAppState
//     FFAppState().routeStarted = _isTracking;
//   }
//   // --------------------------------------------//

//   void _setupSmoothHeadingStream() {
//     FlutterCompass.events?.listen((event) {
//       if (event.heading != null) {
//         _headingBuffer.add(event.heading!);
//         if (_headingBuffer.length > _headingBufferSize) {
//           _headingBuffer.removeAt(0);
//         }
//         double averageHeading =
//             _headingBuffer.reduce((a, b) => a + b) / _headingBuffer.length;
//         _smoothHeadingController.add(_normalizeHeading(averageHeading));
//       }
//     });
//   }

//   double _normalizeHeading(double heading) {
//     // Ensure the heading is always between 0 and 360 degrees
//     return (heading + 360) % 360;
//   }

//   Future<void> _initializeTileProvider() async {
//     final stats = FMTC.FMTCRoot.stats;
//     final stores = await stats.storesAvailable;

//     if (stores.isEmpty) {
//       print("No stores available");
//       return;
//     }

//     // Get the current location
//     Position position = await _getCurrentPositionWithRetry();
//     ll.LatLng currentLocation =
//         ll.LatLng(position.latitude, position.longitude);

//     // Find a store that contains the current location
//     for (var store in stores) {
//       final md = FMTC.FMTCStore(store.storeName).metadata;
//       final metadata = await md.read;
//       if (metadata.containsKey('region_north') &&
//           metadata.containsKey('region_south') &&
//           metadata.containsKey('region_east') &&
//           metadata.containsKey('region_west')) {
//         final north = double.parse(metadata['region_north'] as String);
//         final south = double.parse(metadata['region_south'] as String);
//         final east = double.parse(metadata['region_east'] as String);
//         final west = double.parse(metadata['region_west'] as String);
//         final region = {
//           'north': north,
//           'south': south,
//           'east': east,
//           'west': west,
//         };
//         if (_isLocationInRegion(currentLocation, region)) {
//           _storeName = store.storeName;
//           break;
//         }
//       }
//     }

//     // If no matching store found, use the first store
//     if (_storeName == null && stores.isNotEmpty) {
//       _storeName = stores[0].storeName;
//     }

//     if (_storeName != null) {
//       _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
//         settings: FMTC.FMTCTileProviderSettings(
//           behavior: FMTC.CacheBehavior.cacheFirst,
//         ),
//       );
//       setState(() {}); // Trigger rebuild with the new tile provider
//     } else {
//       print("No suitable store found");
//     }
//   }

//   bool _isLocationInRegion(ll.LatLng location, Map<String, double> region) {
//     return location.latitude >= region['south']! &&
//         location.latitude <= region['north']! &&
//         location.longitude >= region['west']! &&
//         location.longitude <= region['east']!;
//   }

//   // Initialization of current marker
//   Future<void> _initializeLocation() async {
//     try {
//       await _checkLocationPermission();
//       await _checkLocationAccuracy();

//       Position initialPosition = await _getCurrentPositionWithRetry();
//       setState(() {
//         _currentLocation =
//             ll.LatLng(initialPosition.latitude, initialPosition.longitude);
//         _isInitialized = true;
//       });

//       _startLocationStream();
//     } catch (e) {
//       setState(() {
//         _errorMessage = "Initialization error: $e";
//       });
//     }
//   }

//   Future<void> _checkConnectivity() async {
//     var connectivityResult = await (Connectivity().checkConnectivity());
//     setState(() {
//       _isOnline = connectivityResult != ConnectivityResult.none;
//     });
//   }

//   Future<void> _checkLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('Location services are disabled.');

//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Location permissions are denied');
//       }
//     }
//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Location permissions are permanently denied');
//     }
//   }

//   Future<void> _checkLocationAccuracy() async {
//     try {
//       LocationAccuracyStatus accuracy = await Geolocator.getLocationAccuracy();
//       if (accuracy == LocationAccuracyStatus.reduced) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Please enable precise location for better accuracy'),
//             action: SnackBarAction(
//               label: 'Settings',
//               onPressed: () {
//                 Geolocator.openAppSettings();
//               },
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error checking location accuracy: $e');
//     }
//   }

//   //
//   Future<Position> _getCurrentPositionWithRetry({int retries = 0}) async {
//     try {
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.best,
//         timeLimit: Duration(seconds: 10),
//       );
//     } catch (e) {
//       if (retries < _maxRetries) {
//         await Future.delayed(Duration(seconds: 2));
//         return _getCurrentPositionWithRetry(retries: retries + 1);
//       } else {
//         throw Exception(
//             'Failed to get current position after $_maxRetries attempts');
//       }
//     }
//   }

//   void _startLocationStream() {
//     LocationSettings locationSettings = LocationSettings(
//       //AndroidSettings to LocationSettings
//       accuracy: LocationAccuracy.best,
//       distanceFilter: 0,
//       // intervalDuration: const Duration(seconds: 1),
//       // forceLocationManager: true,
//       // foregroundNotificationConfig: const ForegroundNotificationConfig(
//       //   notificationText: "PCIC is tracking your location",
//       //   notificationTitle: "Location Tracking Active",
//       //   enableWakeLock: true,
//     );

//     _positionStreamSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position position) {
//         _processNewPosition(position);
//       },
//       onError: (error) {
//         print("Location stream error: $error");
//         _restartLocationStream();
//       },
//     );
//   }

//   void _restartLocationStream() {
//     _positionStreamSubscription?.cancel();
//     _startLocationStream();
//   }

//   //track new coordinates
//   void _processNewPosition(Position position) {
//     if (!_isTracking) return;
//     print('Position accuracy: ${position.accuracy} meters');
//     if (position.accuracy <= _minAccuracy) {
//       ll.LatLng newLocation = ll.LatLng(position.latitude, position.longitude);
//       _recentLocations.add(newLocation);
//       if (_recentLocations.length > _movingAverageWindow) {
//         _recentLocations.removeAt(0);
//       }
//       ll.LatLng averageLocation = _calculateAverageLocation();

//       if (_startingPosition != null) {
//         double distanceFromStart = _distance.as(
//             ll.LengthUnit.Meter, _startingPosition!, averageLocation);

//         if (distanceFromStart >= _movementThreshold ||
//             _routeCoordinates.length > 1) {
//           _updatePosition(averageLocation);
//         } else {
//           print('Not updating position: Too close to starting point');
//         }
//       } else {
//         _updatePosition(averageLocation);
//       }
//     } else {
//       print('Skipping low accuracy position');
//     }
//   }

//   void _updatePosition(ll.LatLng location) {
//     setState(() {
//       _currentLocation = location;
//       if (_isTracking) {
//         _routeCoordinates.add(_currentLocation!);
//       }
//       if (_isMapReady) {
//         _mapController.move(_currentLocation!, _currentZoom);
//       }
//     });
//   }

//   ll.LatLng _calculateAverageLocation() {
//     double latSum = 0, lonSum = 0;
//     for (var loc in _recentLocations) {
//       latSum += loc.latitude;
//       lonSum += loc.longitude;
//     }
//     return ll.LatLng(
//         latSum / _recentLocations.length, lonSum / _recentLocations.length);
//   }

//   Future<bool> _isGpsEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }

//   Future<void> _startTracking() async {
//     if (_isInitialized && !_isTracking) {
//       bool gpsEnabled = await _isGpsEnabled();
//       if (!gpsEnabled) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content:
//               Text('GPS is not enabled. Please turn on GPS to start tracking.'),
//         ));
//         FFAppState().routeStarted = false;
//         return;
//       }

//       try {
//         setState(() {
//           _isTracking = true;
//           _routeCoordinates.clear();
//           _cornerMarkers.clear();
//           _startingPosition = _currentLocation;
//         });

//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return AlertDialog(
//                 title: Text('Initializing GPS'),
//                 content: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 20),
//                     Text('Please wait for 10 seconds while GPS stabilizes...'),
//                   ],
//                 ),
//               );
//             },
//           );
//         });

//         await Future.delayed(Duration(seconds: 10));

//         Position startPosition = await _getCurrentPositionWithRetry();

//         setState(() {
//           _startingPosition =
//               ll.LatLng(startPosition.latitude, startPosition.longitude);
//           _routeCoordinates.add(_startingPosition!);
//           _cornerMarkers.add(
//             Marker(
//               point: _startingPosition!,
//               child: Icon(Icons.star, color: Colors.red),
//             ),
//           );
//         });

//         Navigator.of(context).pop(); // Dismiss the dialog

//         // Start updating positions
//         _startLocationStream();

//         FFAppState().routeStarted = true;
//       } catch (e) {
//         setState(() {
//           _isTracking = false;
//           _errorMessage = "Failed to start tracking: $e";
//         });
//         FFAppState().routeStarted = false;
//       }
//     }
//   }

//   void _completeTracking() {
//     if (_isTracking) {
//       setState(() {
//         _isTracking = false;
//         if (_routeCoordinates.isNotEmpty &&
//             _routeCoordinates.first != _routeCoordinates.last) {
//           _routeCoordinates.add(_routeCoordinates.first);
//         }
//       });

//       // Convert ll.LatLng to FlutterFlow's LatLng
//       List<LatLng> convertedCoordinates = _routeCoordinates
//           .map((coord) => LatLng(coord.latitude, coord.longitude))
//           .toList();

//       debugPrint('Converted coordinates: $convertedCoordinates');
//       // debugPrint('Task ID: ${FFAppState().currentTaskId}');
//       debugPrint('Saving IDK');

//       /// saveGpx('idk', convertedCoordinates);
//       saveGpx(widget.taskId ?? 'default_task_id', convertedCoordinates);
//     }
//   }

//   void recenterMap() {
//     if (_currentLocation != null && _isMapReady) {
//       _mapController.move(_currentLocation!, _currentZoom);
//     }
//   }

//   @override
//   void dispose() {
//     _smoothHeadingController.close();
//     _positionStreamSubscription?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = FFAppState();

//     if (appState.routeStarted && !_isTracking) {
//       _startTracking();
//     } else if (!appState.routeStarted && _isTracking) {
//       _completeTracking();
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('Error: $_errorMessage'),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _errorMessage = null;
//                   _isInitialized = false;
//                 });
//                 _initializeLocation();
//               },
//               child: Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (!_isInitialized || _currentLocation == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Stack(
//       children: [
//         SizedBox(
//           width: widget.width ?? MediaQuery.of(context).size.width,
//           height: widget.height ?? MediaQuery.of(context).size.height,
//           child: FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _currentLocation!,
//               initialZoom: _currentZoom,
//               minZoom: 16,
//               maxZoom: 22,
//               onMapReady: () {
//                 setState(() {
//                   _isMapReady = true;
//                 });
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate:
//                     'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
//                 additionalOptions: {
//                   'accessToken': widget.accessToken ?? '',
//                 },
//                 tileProvider: _tileProvider,
//               ),
//               CurrentLocationLayer(
//                 alignPositionOnUpdate: AlignOnUpdate.always,
//                 alignDirectionOnUpdate: AlignOnUpdate.never,
//                 alignDirectionStream: _smoothHeadingController.stream,
//                 style: LocationMarkerStyle(
//                   marker: const DefaultLocationMarker(color: Colors.green),
//                   markerSize: const Size(
//                       15, 15), // Slightly larger for better visibility
//                   markerDirection: MarkerDirection.heading,
//                   accuracyCircleColor: Colors.green.withOpacity(0.2),
//                   headingSectorColor: Colors.green.withOpacity(0.8),
//                 ),
//                 alignDirectionAnimationDuration: Duration(
//                     milliseconds: 200), // Slightly slower for smoother rotation
//               ),
//               if (_isTracking)
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routeCoordinates,
//                       strokeWidth: 4.0,
//                       color: Colors.blue,
//                     ),
//                   ],
//                 ),
//               if (!_isTracking && _routeCoordinates.isNotEmpty)
//                 PolygonLayer(
//                   polygons: [
//                     Polygon(
//                       points: _routeCoordinates,
//                       color: Colors.blue.withOpacity(0.2),
//                       borderColor: Colors.blue,
//                       borderStrokeWidth: 3,
//                     ),
//                   ],
//                 ),
//               MarkerLayer(markers: _cornerMarkers),
//             ],
//           ),
//         ),
//         Positioned(
//           top: 50,
//           right: 20,
//           child: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Color(0x7f0f1113),
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.transparent, width: 1),
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(30),
//                 onTap: recenterMap,
//                 child: Center(
//                   child: Icon(
//                     Icons.my_location_outlined,
//                     color: Colors.white,
//                     size: 24,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         Positioned(
//           bottom: 20,
//           right: 20,
//           child: FloatingActionButton(
//             onPressed: _toggleTracking,
//             child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
//           ),
//         ),
//       ],
//     );
//   }
// }
