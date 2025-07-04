import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncnotes/services/connectivity_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef GenericWebSocketNotifierProvider<T>
    = StreamNotifierProvider<WebSocketService<T>, T>;

enum ConnectionState { disconnected, connecting, connected, reconnecting }

class WebSocket<T> {
  WebSocketChannel? _channel;

  Future<bool> createConnection() async {
    try {
      final uri = Uri.parse("wss://echo.websocket.org");
      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready;
      return true;
    } on SocketException {
      log('SocketException occurd');
      return false;
    } on WebSocketChannelException {
      log('WebSocketChannelException occurd');
      return false;
    }
  }

  Future<void> terminateConnection() async {
    _channel?.sink.close();
  }

  void sendMessage(T message) {
    _channel?.sink.add(message);
  }

  Stream<T> get stream {
    if (_channel == null) {
      throw Exception("websocket channel [_channel] not established");
    }
    return _channel!.stream.cast<T>();
  }
}

class WebSocketService<T> extends StreamNotifier<T> {
  late WebSocket<T> _websocketService;
  late StreamSubscription<NetworkStatus> networkSubscription;
  StreamSubscription<T>? _socketSubscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _disposed = false;
  late StreamController<T> _controller;
  ConnectionState _state = ConnectionState.disconnected;
  int _reconnectAttempts = 0;

  ConnectivityService get _connectivity => ref.read(connectivityProvider);

  @override
  Stream<T> build() {
    try {
      initialize();
      ref.onDispose(cleanup);
      return _controller.stream;
    } catch (e) {
      log("Error occured while establishing connection: ${e.toString()}");
      return Stream.error(e);
    }
  }

  void initialize() {
    _websocketService = WebSocket<T>();
    _controller = StreamController<T>.broadcast();
    setupNetworkListener();
    connect();
  }

  Future<void> connect() async {
    if (_disposed || _state == ConnectionState.connected) return;

    _setState(ConnectionState.connecting);

    final isInternetAvailable = await _connectivity.checkConnectivity();

    if (!isInternetAvailable) {
      _setState(ConnectionState.disconnected);
      return;
    }

    _isConnected = await _websocketService.createConnection();

    if (_isConnected) {
      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;
      websocketListener();
    } else {
      _setState(ConnectionState.disconnected);
      reconnect();
    }
  }

  Future<void> reconnect() async {
    if (_isConnected || _reconnectAttempts >= 5) return;
    _setState(ConnectionState.reconnecting);

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: 2 * _reconnectAttempts.clamp(1, 5));
    _reconnectTimer = Timer(delay, () async {
      try {
        _reconnectAttempts++;

        connect();
      } catch (e) {
        log('Reconnect failed: $e');
      }
    });
  }

  Future<void> websocketListener() async {
    _socketSubscription?.cancel();
    _socketSubscription = _websocketService.stream.listen(
      (data) {
        if (!_controller.isClosed) {
          _controller.sink.add(data);
        }
      },
      onError: (error) {
        log('Socket error: $error');
        _controller.addError(error);
        reconnect();
      },
      onDone: () {
        _setState(ConnectionState.disconnected);
        reconnect();
      },
    );
  }

  Future<void> setupNetworkListener() async {
    networkSubscription = _connectivity.stream.listen((networkStatus) async {
      if (networkStatus == NetworkStatus.notConnected) {
        _reconnectTimer?.cancel();
        _websocketService.terminateConnection();
        _isConnected = false;
      } else {
        await reconnect();
      }
    });
  }

  void sendMessage(T message) {
    _websocketService.sendMessage(message);
  }

  void _setState(ConnectionState newState) {
    _state = newState;
  }

  ConnectionState get connectionState => _state;

  void disconnect() {
    _socketSubscription?.cancel();
    _controller.close();
    _websocketService.terminateConnection();
    _reconnectTimer?.cancel();
    _setState(ConnectionState.disconnected);
  }

  void cleanup() {
    if (_disposed) return;
    _disposed = true;
    _websocketService.terminateConnection();
    networkSubscription.cancel();
    _socketSubscription?.cancel();
    _controller.close();
    _reconnectTimer?.cancel();
  }
}

class WebSocketProvider {
  static final websocketRegistry = <Type, StreamNotifierProvider>{};

  static GenericWebSocketNotifierProvider<T> get<T>() {
    if (!websocketRegistry.containsKey(T)) {
      websocketRegistry[T] = GenericWebSocketNotifierProvider<T>(
        WebSocketService<T>.new,
      );
    }
    return websocketRegistry[T] as GenericWebSocketNotifierProvider<T>;
  }
}
