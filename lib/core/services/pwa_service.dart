import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pwaServiceProvider = Provider((ref) => PwaService());

class PwaService {
  final _isInstallableController = StreamController<bool>.broadcast();
  Stream<bool> get isInstallable => _isInstallableController.stream;

  final _updateAvailableController = StreamController<void>.broadcast();
  Stream<void> get updateAvailable => _updateAvailableController.stream;

  PwaService() {
    if (kIsWeb) {
      _initJsCallbacks();
    }
  }

  void _initJsCallbacks() {
    // Callback when browser says app can be installed
    js.context['onAppInstallable'] = () {
      _isInstallableController.add(true);
    };

    // Callback when service worker detects an update
    js.context['onAppUpdateAvailable'] = () {
      _updateAvailableController.add(null);
    };
  }

  Future<bool> promptInstall() async {
    if (!kIsWeb) return false;

    final result = await js.context.callMethod('presentInstallPrompt');
    if (result == true) {
      _isInstallableController.add(false);
      return true;
    }
    return false;
  }

  void reloadApp() {
    if (kIsWeb) {
      js.context.callMethod('location.reload');
    }
  }

  void dispose() {
    _isInstallableController.close();
    _updateAvailableController.close();
  }
}
