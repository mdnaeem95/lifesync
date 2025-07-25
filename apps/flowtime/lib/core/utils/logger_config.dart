import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

/// Configure logging for the FlowTime app
class LoggerConfig {
  static void configure() {
    // Set the root logging level based on build mode
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    
    // Configure log output
    Logger.root.onRecord.listen((record) {
      final time = record.time.toLocal();
      final formattedTime = '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}:'
          '${time.second.toString().padLeft(2, '0')}';
      
      final level = record.level.name.padRight(7);
      final logger = record.loggerName.padRight(20);
      
      // Format the output
      var output = '[$formattedTime] $level $logger: ${record.message}';
      
      // Add error and stack trace if present
      if (record.error != null) {
        output += '\nError: ${record.error}';
      }
      if (record.stackTrace != null) {
        output += '\nStack trace:\n${record.stackTrace}';
      }
      
      // Use debugPrint to avoid Flutter's print throttling in release mode
      debugPrint(output);
    });
  }
  
  /// Create a logger for a specific class or module
  static Logger getLogger(String name) {
    return Logger(name);
  }
}

/// Extension to make logging easier
extension LoggerExtension on Logger {
  /// Log a debug message (only in debug mode)
  void debug(String message) {
    if (kDebugMode) {
      fine(message);
    }
  }
  
  /// Log an error with optional error object and stack trace
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    severe(message, error, stackTrace);
  }
  
  /// Log a warning
  void warn(String message) {
    warning(message);
  }
}