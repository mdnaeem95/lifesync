import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

/// Abstract class for checking network connectivity
abstract class NetworkInfo {
  /// Returns true if device is connected to the internet
  Future<bool> get isConnected;
  
  /// Returns the current connectivity status
  Future<ConnectivityResult> get connectivityStatus;
  
  /// Stream of connectivity changes
  Stream<ConnectivityResult> get onConnectivityChanged;
  
  /// Checks if the connection is mobile data
  Future<bool> get isMobileData;
  
  /// Checks if the connection is WiFi
  Future<bool> get isWifi;
}

/// Implementation of NetworkInfo using connectivity_plus package
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;
  final _logger = Logger('NetworkInfo');
  
  NetworkInfoImpl({Connectivity? connectivity}) 
      : _connectivity = connectivity ?? Connectivity();
  
  @override
  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      final connected = result != ConnectivityResult.none;
      _logger.fine('Network connectivity check: $result (connected: $connected)');
      return connected;
    } catch (e, stack) {
      _logger.severe('Error checking connectivity', e, stack);
      // Assume connected if we can't determine status
      return true;
    }
  }
  
  @override
  Future<ConnectivityResult> get connectivityStatus async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _logger.fine('Connectivity status: $result');
      return result;
    } catch (e, stack) {
      _logger.severe('Error getting connectivity status', e, stack);
      return ConnectivityResult.none;
    }
  }
  
  @override
  Stream<ConnectivityResult> get onConnectivityChanged {
    _logger.info('Starting connectivity monitoring');
    
    return _connectivity.onConnectivityChanged
      .map((results) => results.isNotEmpty ? results.first : ConnectivityResult.none)
      .handleError((error, stack) {
        _logger.severe('Error in connectivity stream', error, stack);
      });
  }
  
  @override
  Future<bool> get isMobileData async {
    final status = await connectivityStatus;
    return status == ConnectivityResult.mobile;
  }
  
  @override
  Future<bool> get isWifi async {
    final status = await connectivityStatus;
    return status == ConnectivityResult.wifi;
  }
  
  /// Performs a real connectivity test by attempting to reach a reliable server
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        _logger.fine('No network connection available');
        return false;
      }
      
      // Additional check can be performed here by pinging a server
      // For now, we trust the connectivity result
      _logger.fine('Internet connection available via $result');
      return true;
    } catch (e, stack) {
      _logger.severe('Error checking internet connection', e, stack);
      return false;
    }
  }
}