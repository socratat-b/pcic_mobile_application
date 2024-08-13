import '/auth/supabase_auth/auth_util.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'offline_tasks_and_ppir_list_widget.dart'
    show OfflineTasksAndPpirListWidget;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class OfflineTasksAndPpirListModel
    extends FlutterFlowModel<OfflineTasksAndPpirListWidget> {
  ///  Local state fields for this page.

  int? limit = 0;

  int? iteration = 0;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<TasksRow>? onlineTasks;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<PpirFormsRow>? ppirOutput;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
