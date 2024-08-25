import '/backend/sqlite/sqlite_manager.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'offline_sync_widget.dart' show OfflineSyncWidget;
import 'package:flutter/material.dart';

class OfflineSyncModel extends FlutterFlowModel<OfflineSyncWidget> {
  ///  Local state fields for this page.

  int? limit = 0;

  int? iteration = 0;

  bool isSync = false;

  bool startSync = false;

  bool isSynced = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - Query Rows] action in Container widget.
  List<TasksRow>? onlineTasks;
  // Stores action output result for [Backend Call - Query Rows] action in Container widget.
  List<PpirFormsRow>? ppirOutput;
  // Stores action output result for [Backend Call - SQLite (OFFLINE select REGION CODE)] action in Container widget.
  List<OFFLINESelectREGIONCODERow>? regionCode;
  // Stores action output result for [Custom Action - syncFromFTP] action in Container widget.
  bool? isSyced;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
