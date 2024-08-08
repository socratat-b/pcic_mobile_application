import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/material.dart';

Future updateUserStatusIfOnline(BuildContext context) async {
  if (FFAppState().ONLINE) {
    await UsersTable().update(
      data: {
        'is_online': true,
      },
      matchingRows: (rows) => rows.eq(
        'auth_user_id',
        currentUserUid,
      ),
    );
  } else {
    await UsersTable().update(
      data: {
        'is_online': false,
      },
      matchingRows: (rows) => rows.eq(
        'auth_user_id',
        currentUserUid,
      ),
    );
  }
}

Future updateLogs(BuildContext context) async {}

Future<UsersRow?> queryCurrentUserProfile(BuildContext context) async {
  List<UsersRow>? currentUserProfile;

  currentUserProfile = await UsersTable().queryRows(
    queryFn: (q) => q.eq(
      'email',
      currentUserEmail,
    ),
  );

  return null;
}

Future permissionBlock(BuildContext context) async {
  if (await getPermissionStatus(cameraPermission)) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Camera access granted',
          style: TextStyle(),
        ),
        duration: const Duration(milliseconds: 4000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  } else {
    await requestPermission(cameraPermission);
  }

  if (await getPermissionStatus(photoLibraryPermission)) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Photo Library access granted',
          style: TextStyle(),
        ),
        duration: const Duration(milliseconds: 4000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  } else {
    await requestPermission(photoLibraryPermission);
  }

  if (await getPermissionStatus(locationPermission)) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Location access granted',
          style: TextStyle(),
        ),
        duration: const Duration(milliseconds: 4000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  } else {
    await requestPermission(locationPermission);
  }

  if (await getPermissionStatus(notificationsPermission)) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Notification access granted',
          style: TextStyle(),
        ),
        duration: const Duration(milliseconds: 4000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  } else {
    await requestPermission(notificationsPermission);
  }
}
