import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_pre_alert_page.dart';
import 'permission_types.dart';

export 'permission_types.dart';

class PermissionGuard {
  static bool _isAllowed(PermissionStatus status) {
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  static Future<PermissionStatus> _filePermissionStatus() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      if (_isAllowed(storage)) {
        return storage;
      }
      final photos = await Permission.photos.status;
      return _isAllowed(photos) ? photos : storage;
    }

    return Permission.photos.status;
  }

  static Future<bool> hasPermission(RequiredPermission permission) async {
    switch (permission) {
      case RequiredPermission.camera:
        return _isAllowed(await Permission.camera.status);
      case RequiredPermission.file:
        return _isAllowed(await _filePermissionStatus());
      case RequiredPermission.location:
        return _isAllowed(await Permission.locationWhenInUse.status);
    }
  }

  static Future<bool> ensurePermission(
    BuildContext context,
    RequiredPermission permission,
  ) async {
    final granted = await hasPermission(permission);
    if (granted) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PermissionPreAlertPage(
          forceGrantAll: false,
          requiredPermissions: {permission},
        ),
      ),
    );

    if (!context.mounted) {
      return false;
    }

    return hasPermission(permission);
  }
}
