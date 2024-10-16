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

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:xml/xml.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;

class MapBase64 extends StatefulWidget {
  const MapBase64({
    Key? key,
    this.width,
    this.height,
    this.blob,
    required this.accessToken,
  }) : super(key: key);

  final double? width;
  final double? height;
  final String? blob;
  final String accessToken;

  @override
  State<MapBase64> createState() => _MapBase64State();
}

class _MapBase64State extends State<MapBase64> {
  List<latlong.LatLng> _coordinates = [];
  late final MapController _mapController;
  double _currentZoom = 18.0;
  bool _isLoading = true;
  TileProvider? _tileProvider;
  String? _storeName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      if (widget.blob != null) {
        _parseGPX(widget.blob!);
      }
      await _initializeTileProvider();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeTileProvider() async {
    if (_coordinates.isEmpty) {
      print('No coordinates available');
      return;
    }

    var currentLocation = _coordinates.first;
    print(
        'Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');

    final stats = FMTC.FMTCRoot.stats;
    final stores = await stats.storesAvailable;

    print('Available stores: ${stores.length}');

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
      _tileProvider = FMTC.FMTCStore(_storeName!).getTileProvider(
        settings: FMTC.FMTCTileProviderSettings(
          behavior: FMTC.CacheBehavior.cacheFirst,
        ),
      );
      print('Tile provider initialized with store: $_storeName');
      print('_tileProvider: $_tileProvider');
    } else {
      print('No store available to initialize tile provider');
    }
  }

  bool _isLocationInRegion(latlong.LatLng location, Map<String, num> region) {
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

  void _parseGPX(String base64Data) {
    try {
      final document = XmlDocument.parse(utf8.decode(base64Decode(base64Data)));
      _coordinates = document.findAllElements('trkpt').map((trkpt) {
        return latlong.LatLng(
          double.parse(trkpt.getAttribute('lat')!),
          double.parse(trkpt.getAttribute('lon')!),
        );
      }).toList();

      WidgetsBinding.instance.addPostFrameCallback((_) => _centerMap());
    } catch (e) {
      print('Error parsing GPX data: $e');
      _errorMessage = 'Error parsing GPX data: $e';
    }
  }

  void _centerMap() {
    if (_coordinates.isNotEmpty) {
      final bounds = _calculateBounds(_coordinates);
      final centerLat = (bounds[0] + bounds[2]) / 2;
      final centerLon = (bounds[1] + bounds[3]) / 2;
      _currentZoom = _calculateZoom(bounds);
      _mapController.move(latlong.LatLng(centerLat, centerLon), _currentZoom);
    }
  }

  List<double> _calculateBounds(List<latlong.LatLng> points) {
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (var point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }
    return [minLat, minLon, maxLat, maxLon];
  }

  double _calculateZoom(List<double> bounds) {
    const WORLD_PX = 256.0;
    const ZOOM_MAX = 21.0;
    const ZOOM_MIN = 1.0;

    final latFraction = (bounds[2] - bounds[0]) / 180.0;
    final lonFraction = (bounds[3] - bounds[1]) / 360.0;

    final latZoom = math.log(WORLD_PX / latFraction) / math.ln2;
    final lonZoom = math.log(WORLD_PX / lonFraction) / math.ln2;

    return math.min(latZoom, lonZoom).clamp(ZOOM_MIN, ZOOM_MAX) - 1;
  }

  void _zoomIn() {
    _currentZoom = math.min(_currentZoom + 1, 21);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = math.max(_currentZoom - 1, 1);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_coordinates.isEmpty) {
      return Center(child: Text('No GPS data available'));
    }

    return Stack(
      children: [
        Container(
          width: widget.width,
          height: widget.height,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              minZoom: 18,
              maxZoom: 22,
              initialCenter: _coordinates.first,
              initialZoom: _currentZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}@2x?access_token=${widget.accessToken}',
                additionalOptions: {'accessToken': widget.accessToken},
                tileProvider: _tileProvider,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _coordinates,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              FloatingActionButton(
                mini: true,
                child: Icon(Icons.add),
                onPressed: _zoomIn,
              ),
              SizedBox(height: 8),
              FloatingActionButton(
                mini: true,
                child: Icon(Icons.remove),
                onPressed: _zoomOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
