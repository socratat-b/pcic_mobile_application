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

/// The function `syncOnlineTaskAndPpirToOffline` synchronizes offline tasks and PPIR forms with online
/// data and updates the local database accordingly.
///
/// Returns:
///   The function `syncOnlineTaskAndPpirToOffline` returns a `Future<String>` which contains a message
/// indicating the result of the synchronization process. If the synchronization is successful, it
/// returns a message stating the number of updated online PPIR forms and the count of new offline tasks
/// and PPIR forms added. If the synchronization fails, it returns a message stating "Sync failed".
import '/auth/supabase_auth/auth_util.dart';

Future<String> syncOnlineTaskAndPpirToOffline() async {
  try {
    int updatedOnlineTasksCount = 0;
    int updatedOnlinePPIRFormsCount = 0;
    int newOfflineTasksCount = 0;
    int newOfflinePPIRFormsCount = 0;

    print('Starting Step 1a: Sync offline tasks to online');
    List<OFFLINESelectAllTasksByAssigneeRow> offlineTasks =
        await SQLiteManager.instance.oFFLINESelectAllTasksByAssignee(
      assignee: currentUserUid,
    );
    print('Fetched ${offlineTasks.length} offline tasks.');

    for (var offlineTask in offlineTasks) {
      var onlineTaskExists = await TasksTable().queryRows(
        queryFn: (q) => q.eq('id', offlineTask.id),
      );

      if (onlineTaskExists.isNotEmpty) {
        await TasksTable().update(
          data: {'status': offlineTask.status},
          matchingRows: (row) => row.eq('id', offlineTask.id),
        );
        updatedOnlineTasksCount++;
      }
    }

    print('Updated $updatedOnlineTasksCount online task statuses.');

    print('Starting Step 1b: Sync offline PPIR forms to online');
    List<SELECTPPIRFormsByAssigneeRow> offlinePPIRForms =
        await SQLiteManager.instance.sELECTPPIRFormsByAssignee(
      assignee: currentUserUid,
    );
    print('Fetched ${offlinePPIRForms.length} offline PPIR forms.');

    for (var offlinePPIR in offlinePPIRForms) {
      bool isPpirDirty =
          offlinePPIR.ppirIsDirty == 'true' || offlinePPIR.ppirIsDirty == '1';

      if (isPpirDirty) {
        var onlinePPIRFormExists = await PpirFormsTable().queryRows(
          queryFn: (q) => q.eq('task_id', offlinePPIR.taskId),
        );

        if (onlinePPIRFormExists.isNotEmpty) {
          await PpirFormsTable().update(
            data: {
              'ppir_assignmentid': offlinePPIR.ppirAssignmentid,
              'gpx': offlinePPIR.gpx,
              'ppir_insuranceid': offlinePPIR.ppirInsuranceid,
              'ppir_farmername': offlinePPIR.ppirFarmername,
              'ppir_address': offlinePPIR.ppirAddress,
              'ppir_farmertype': offlinePPIR.ppirFarmertype,
              'ppir_mobileno': offlinePPIR.ppirMobileno,
              'ppir_groupname': offlinePPIR.ppirGroupname,
              'ppir_groupaddress': offlinePPIR.ppirGroupaddress,
              'ppir_lendername': offlinePPIR.ppirLendername,
              'ppir_lenderaddress': offlinePPIR.ppirLenderaddress,
              'ppir_cicno': offlinePPIR.ppirCicno,
              'ppir_farmloc': offlinePPIR.ppirFarmloc,
              'ppir_north': offlinePPIR.ppirNorth,
              'ppir_south': offlinePPIR.ppirSouth,
              'ppir_east': offlinePPIR.ppirEast,
              'ppir_west': offlinePPIR.ppirWest,
              'ppir_area_aci': offlinePPIR.ppirAreaAci,
              'ppir_area_act': offlinePPIR.ppirAreaAct,
              'ppir_dopds_aci': offlinePPIR.ppirDopdsAci,
              'ppir_dopds_act': offlinePPIR.ppirDopdsAct,
              'ppir_doptp_aci': offlinePPIR.ppirDoptpAci,
              'ppir_doptp_act': offlinePPIR.ppirDoptpAct,
              'ppir_svp_aci': offlinePPIR.ppirSvpAci,
              'ppir_variety': offlinePPIR.ppirVariety,
              'ppir_stagecrop': offlinePPIR.ppirStagecrop,
              'ppir_remarks': offlinePPIR.ppirRemarks,
              'ppir_name_insured': offlinePPIR.ppirNameInsured,
              'ppir_name_iuia': offlinePPIR.ppirNameIuia,
              'ppir_sig_insured': offlinePPIR.ppirSigInsured,
              'ppir_sig_iuia': offlinePPIR.ppirSigIuia,
              'track_last_coord': offlinePPIR.trackLastCoord,
              'track_date_time': offlinePPIR.trackDateTime,
              'track_total_area': offlinePPIR.trackTotalArea,
              'track_total_distance': offlinePPIR.trackTotalDistance,
              'captured_area': offlinePPIR.capturedArea,
              'sync_status': 'synced',
              'is_dirty': false,
            },
            matchingRows: (row) => row.eq('task_id', offlinePPIR.taskId),
          );
          updatedOnlinePPIRFormsCount++;
        }
      }
    }

    print('Starting Step 2: Clearing offline database');
    await SQLiteManager.instance.dELETEAllRowsForTASKSAndPPIR();
    print('Cleared offline database');

    print('Starting Step 3: Sync online data to offline');
    List<TasksRow> onlineTasks = await TasksTable().queryRows(
      queryFn: (q) => q.eq('assignee', currentUserUid),
    );
    print('Fetched ${onlineTasks.length} online tasks.');

    for (var onlineTask in onlineTasks) {
      await SQLiteManager.instance.insertOfflineTask(
        id: onlineTask.id,
        taskNumber: onlineTask.taskNumber,
        serviceGroup: onlineTask.serviceGroup ?? '',
        status: onlineTask.status,
        serviceType: onlineTask.serviceType,
        priority: onlineTask.priority ?? '',
        assignee: onlineTask.assignee ?? '',
        dateAdded: onlineTask.dateAdded?.toIso8601String() ?? '',
        dateAccess: onlineTask.dateAccess?.toIso8601String() ?? '',
        fileId: onlineTask.fileId ?? '',
      );
      newOfflineTasksCount++;

      var ppirForms = await PpirFormsTable().queryRows(
        queryFn: (q) => q.eq('task_id', onlineTask.id),
      );

      if (ppirForms.isNotEmpty) {
        var ppir = ppirForms.first;
        await SQLiteManager.instance.insertOfflinePPIRForm(
          taskId: ppir.taskId,
          ppirAssignmentId: ppir.ppirAssignmentid,
          gpx: ppir.gpx ?? '',
          ppirInsuranceId: ppir.ppirInsuranceid ?? '',
          ppirFarmerName: ppir.ppirFarmername ?? '',
          ppirAddress: ppir.ppirAddress ?? '',
          ppirFarmerType: ppir.ppirFarmertype ?? '',
          ppirMobileNo: ppir.ppirMobileno ?? '',
          ppirGroupName: ppir.ppirGroupname ?? '',
          ppirGroupAddress: ppir.ppirGroupaddress ?? '',
          ppirLenderName: ppir.ppirLendername ?? '',
          ppirLenderAddress: ppir.ppirLenderaddress ?? '',
          ppirCICNo: ppir.ppirCicno ?? '',
          ppirFarmLoc: ppir.ppirFarmloc ?? '',
          ppirNorth: ppir.ppirNorth ?? '',
          ppirSouth: ppir.ppirSouth ?? '',
          ppirEast: ppir.ppirEast ?? '',
          ppirWest: ppir.ppirWest ?? '',
          ppirAtt1: ppir.ppirAtt1 ?? '',
          ppirAtt2: ppir.ppirAtt2 ?? '',
          ppirAtt3: ppir.ppirAtt3 ?? '',
          ppirAtt4: ppir.ppirAtt4 ?? '',
          ppirAreaAci: ppir.ppirAreaAci ?? '',
          ppirAreaAct: ppir.ppirAreaAct ?? '',
          ppirDopdsAci: ppir.ppirDopdsAci ?? '',
          ppirDopdsAct: ppir.ppirDopdsAct ?? '',
          ppirDoptpAci: ppir.ppirDoptpAci ?? '',
          ppirDoptpAct: ppir.ppirDoptpAct ?? '',
          ppirSvpAci: ppir.ppirSvpAci ?? '',
          ppirSvpAct: ppir.ppirSvpAct,
          ppirVariety: ppir.ppirVariety ?? '',
          ppirStageCrop: ppir.ppirStagecrop ?? '',
          ppirRemarks: ppir.ppirRemarks ?? '',
          ppirNameInsured: ppir.ppirNameInsured ?? '',
          ppirNameIUIA: ppir.ppirNameIuia ?? '',
          ppirSigInsured: ppir.ppirSigInsured ?? '',
          ppirSigIUIA: ppir.ppirSigIuia ?? '',
          trackLastCoord: ppir.trackLastCoord ?? '',
          trackDateTime: ppir.trackDateTime ?? '',
          trackTotalArea: ppir.trackTotalArea ?? '',
          trackTotalDistance: ppir.trackTotalDistance ?? '',
          capturedArea: ppir.capturedArea ?? '',
          createdAt: ppir.createdAt?.toIso8601String() ?? '',
          updatedAt: ppir.updatedAt?.toIso8601String() ?? '',
          syncStatus: 'synced',
          lastSyncedAt: DateTime.now().toIso8601String(),
          isDirty: 'false',
        );
        newOfflinePPIRFormsCount++;
      } else {
        // Insert a placeholder PPIR form if none exists
        await SQLiteManager.instance.insertOfflinePPIRForm(
          taskId: onlineTask.id,
          ppirAssignmentId: '',
          gpx: '',
          ppirInsuranceId: '',
          ppirFarmerName: '',
          ppirAddress: '',
          ppirFarmerType: '',
          ppirMobileNo: '',
          ppirGroupName: '',
          ppirGroupAddress: '',
          ppirLenderName: '',
          ppirLenderAddress: '',
          ppirCICNo: '',
          ppirFarmLoc: '',
          ppirNorth: '',
          ppirSouth: '',
          ppirEast: '',
          ppirWest: '',
          ppirAtt1: '',
          ppirAtt2: '',
          ppirAtt3: '',
          ppirAtt4: '',
          ppirAreaAci: '',
          ppirAreaAct: '',
          ppirDopdsAci: '',
          ppirDopdsAct: '',
          ppirDoptpAci: '',
          ppirDoptpAct: '',
          ppirSvpAci: '',
          ppirSvpAct: '',
          ppirVariety: '',
          ppirStageCrop: '',
          ppirRemarks: '',
          ppirNameInsured: '',
          ppirNameIUIA: '',
          ppirSigInsured: '',
          ppirSigIUIA: '',
          trackLastCoord: '',
          trackDateTime: '',
          trackTotalArea: '',
          trackTotalDistance: '',
          capturedArea: '',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          syncStatus: 'synced',
          lastSyncedAt: DateTime.now().toIso8601String(),
          isDirty: 'false',
        );
        newOfflinePPIRFormsCount++;
      }
    }

    print('Sync completed successfully');
    return 'Updated $updatedOnlinePPIRFormsCount, Added $newOfflineTasksCount/$newOfflinePPIRFormsCount';
  } catch (e) {
    return 'Sync failed';
  }
}
