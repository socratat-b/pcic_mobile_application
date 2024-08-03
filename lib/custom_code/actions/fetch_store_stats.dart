// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;

Future<void> fetchStoreStats() async {
  try {
    final stats = FMTC.FMTCRoot.stats;

    // Fetch the statistics
    final storesAvailable = await stats.storesAvailable;
    final realSize = await stats.realSize;
    final size = await stats.size;
    final length = await stats.length;

    // Print the statistics
    print('FMTC Statistics:');
    print('Stores Available: $storesAvailable');
    print('Real Size: ${realSize.toStringAsFixed(2)} KiB');
    print('Size: ${size.toStringAsFixed(2)} KiB');
    print('Total Tiles: $length');

    // Fetch and print information for each store
    for (final store in await stats.storesAvailable) {
      final storeStats = FMTC.FMTCRoot.stats;
      final storeRealSize = await storeStats.realSize;
      final storeSize = await storeStats.size;
      final storeLength = await storeStats.length;

      print('\nStore: $store');
      print('Real Size: ${storeRealSize.toStringAsFixed(2)} KiB');
      print('Size: ${storeSize.toStringAsFixed(2)} KiB');
      print('Tiles: $storeLength');
    }
  } catch (e) {
    print('Error fetching FMTC stats: $e');
  }
}
