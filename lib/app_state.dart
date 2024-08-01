import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';
import 'backend/api_requests/api_manager.dart';
import 'backend/supabase/supabase.dart';
import '/backend/sqlite/sqlite_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:csv/csv.dart';
import 'package:synchronized/synchronized.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    secureStorage = FlutterSecureStorage();
    await _safeInitAsync(() async {
      _AUTHID = await secureStorage.getString('ff_AUTHID') ?? _AUTHID;
    });
    await _safeInitAsync(() async {
      _mapDownloadProgress =
          await secureStorage.getDouble('ff_mapDownloadProgress') ??
              _mapDownloadProgress;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late FlutterSecureStorage secureStorage;

  bool _ONLINE = false;
  bool get ONLINE => _ONLINE;
  set ONLINE(bool value) {
    _ONLINE = value;
  }

  bool _routeStarted = false;
  bool get routeStarted => _routeStarted;
  set routeStarted(bool value) {
    _routeStarted = value;
  }

  String _AUTHID = '';
  String get AUTHID => _AUTHID;
  set AUTHID(String value) {
    _AUTHID = value;
    secureStorage.setString('ff_AUTHID', value);
  }

  void deleteAUTHID() {
    secureStorage.delete(key: 'ff_AUTHID');
  }

  bool _startMapDownload = false;
  bool get startMapDownload => _startMapDownload;
  set startMapDownload(bool value) {
    _startMapDownload = value;
  }

  double _mapDownloadProgress = 0.0;
  double get mapDownloadProgress => _mapDownloadProgress;
  set mapDownloadProgress(double value) {
    _mapDownloadProgress = value;
    secureStorage.setDouble('ff_mapDownloadProgress', value);
  }

  void deleteMapDownloadProgress() {
    secureStorage.delete(key: 'ff_mapDownloadProgress');
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}

extension FlutterSecureStorageExtensions on FlutterSecureStorage {
  static final _lock = Lock();

  Future<void> writeSync({required String key, String? value}) async =>
      await _lock.synchronized(() async {
        await write(key: key, value: value);
      });

  void remove(String key) => delete(key: key);

  Future<String?> getString(String key) async => await read(key: key);
  Future<void> setString(String key, String value) async =>
      await writeSync(key: key, value: value);

  Future<bool?> getBool(String key) async => (await read(key: key)) == 'true';
  Future<void> setBool(String key, bool value) async =>
      await writeSync(key: key, value: value.toString());

  Future<int?> getInt(String key) async =>
      int.tryParse(await read(key: key) ?? '');
  Future<void> setInt(String key, int value) async =>
      await writeSync(key: key, value: value.toString());

  Future<double?> getDouble(String key) async =>
      double.tryParse(await read(key: key) ?? '');
  Future<void> setDouble(String key, double value) async =>
      await writeSync(key: key, value: value.toString());

  Future<List<String>?> getStringList(String key) async =>
      await read(key: key).then((result) {
        if (result == null || result.isEmpty) {
          return null;
        }
        return CsvToListConverter()
            .convert(result)
            .first
            .map((e) => e.toString())
            .toList();
      });
  Future<void> setStringList(String key, List<String> value) async =>
      await writeSync(key: key, value: ListToCsvConverter().convert([value]));
}
