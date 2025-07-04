import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { connected, notConnected }

final connectivityProvider = StateProvider.autoDispose<ConnectivityService>(
  (ref) => ConnectivityService(),
);

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((o) {
      if (o.contains(ConnectivityResult.none)) {
        _controller.sink.add(NetworkStatus.notConnected);
      } else {
        _controller.sink.add(NetworkStatus.connected);
      }
    });
  }

  Stream<NetworkStatus> get stream => _controller.stream;

  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  void dispose() => _controller.close();
}
