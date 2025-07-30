import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/weekly_planning_data_model.dart';
import '../models/weekly_stats_model.dart';

abstract class WeeklyPlanningLocalDataSource {
  Future<void> cacheWeeklySchedule(WeeklyPlanningDataModel schedule);
  Future<WeeklyPlanningDataModel?> getCachedWeeklySchedule(DateTime weekStart);
  Future<void> cacheWeeklyStats(DateTime weekStart, WeeklyStatsModel stats);
  Future<WeeklyStatsModel?> getCachedWeeklyStats(DateTime weekStart);
  Future<void> cacheEnergyPredictions(DateTime weekStart, Map<int, Map<int, int>> predictions);
  Future<Map<int, Map<int, int>>?> getCachedEnergyPredictions(DateTime weekStart);
  Future<void> clearWeeklyCache(DateTime weekStart);
  Future<void> clearAllCache();
}

class WeeklyPlanningLocalDataSourceImpl implements WeeklyPlanningLocalDataSource {
  final SharedPreferences _sharedPreferences;
  final _logger = Logger('WeeklyPlanningLocalDataSource');
  
  static const String _schedulePrefix = 'WEEKLY_SCHEDULE_';
  static const String _statsPrefix = 'WEEKLY_STATS_';
  static const String _energyPrefix = 'WEEKLY_ENERGY_';
  static const String _cacheTimestampPrefix = 'CACHE_TIMESTAMP_';
  static const Duration _cacheValidDuration = Duration(hours: 1);

  WeeklyPlanningLocalDataSourceImpl({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  @override
  Future<void> cacheWeeklySchedule(WeeklyPlanningDataModel schedule) async {
    _logger.info('Caching weekly schedule for week starting: ${schedule.weekStartDate}');
    
    try {
      final key = _getScheduleKey(schedule.weekStartDate);
      final jsonString = json.encode(schedule.toJson());
      
      await _sharedPreferences.setString(key, jsonString);
      await _setCacheTimestamp(key);
      
      _logger.fine('Weekly schedule cached successfully');
    } catch (e, stack) {
      _logger.severe('Error caching weekly schedule', e, stack);
      throw CacheException('Failed to cache weekly schedule');
    }
  }

  @override
  Future<WeeklyPlanningDataModel?> getCachedWeeklySchedule(DateTime weekStart) async {
    _logger.info('Retrieving cached weekly schedule for week starting: $weekStart');
    
    try {
      final key = _getScheduleKey(weekStart);
      
      if (!_isCacheValid(key)) {
        _logger.fine('Cache expired or not found');
        return null;
      }
      
      final jsonString = _sharedPreferences.getString(key);
      if (jsonString == null) {
        _logger.fine('No cached schedule found');
        return null;
      }
      
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final schedule = WeeklyPlanningDataModel.fromJson(jsonData);
      
      _logger.info('Retrieved cached schedule with ${schedule.tasks.length} tasks');
      return schedule;
    } catch (e, stack) {
      _logger.severe('Error retrieving cached schedule', e, stack);
      return null;
    }
  }

  @override
  Future<void> cacheWeeklyStats(DateTime weekStart, WeeklyStatsModel stats) async {
    _logger.info('Caching weekly stats for week starting: $weekStart');
    
    try {
      final key = _getStatsKey(weekStart);
      final jsonString = json.encode(stats.toJson());
      
      await _sharedPreferences.setString(key, jsonString);
      await _setCacheTimestamp(key);
      
      _logger.fine('Weekly stats cached successfully');
    } catch (e, stack) {
      _logger.severe('Error caching weekly stats', e, stack);
      throw CacheException('Failed to cache weekly stats');
    }
  }

  @override
  Future<WeeklyStatsModel?> getCachedWeeklyStats(DateTime weekStart) async {
    _logger.info('Retrieving cached weekly stats for week starting: $weekStart');
    
    try {
      final key = _getStatsKey(weekStart);
      
      if (!_isCacheValid(key)) {
        _logger.fine('Stats cache expired or not found');
        return null;
      }
      
      final jsonString = _sharedPreferences.getString(key);
      if (jsonString == null) {
        _logger.fine('No cached stats found');
        return null;
      }
      
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final stats = WeeklyStatsModel.fromJson(jsonData);
      
      _logger.info('Retrieved cached stats: ${stats.totalTasks} tasks, ${stats.completionRate}% completion');
      return stats;
    } catch (e, stack) {
      _logger.severe('Error retrieving cached stats', e, stack);
      return null;
    }
  }

  @override
  Future<void> cacheEnergyPredictions(
    DateTime weekStart,
    Map<int, Map<int, int>> predictions,
  ) async {
    _logger.info('Caching energy predictions for week starting: $weekStart');
    
    try {
      final key = _getEnergyKey(weekStart);
      
      // Convert to JSON-friendly format
      final jsonData = <String, dynamic>{};
      predictions.forEach((day, hours) {
        final hoursJson = <String, dynamic>{};
        hours.forEach((hour, energy) {
          hoursJson[hour.toString()] = energy;
        });
        jsonData[day.toString()] = hoursJson;
      });
      
      final jsonString = json.encode(jsonData);
      await _sharedPreferences.setString(key, jsonString);
      await _setCacheTimestamp(key);
      
      _logger.fine('Energy predictions cached successfully');
    } catch (e, stack) {
      _logger.severe('Error caching energy predictions', e, stack);
      throw CacheException('Failed to cache energy predictions');
    }
  }

  @override
  Future<Map<int, Map<int, int>>?> getCachedEnergyPredictions(DateTime weekStart) async {
    _logger.info('Retrieving cached energy predictions for week starting: $weekStart');
    
    try {
      final key = _getEnergyKey(weekStart);
      
      if (!_isCacheValid(key)) {
        _logger.fine('Energy cache expired or not found');
        return null;
      }
      
      final jsonString = _sharedPreferences.getString(key);
      if (jsonString == null) {
        _logger.fine('No cached energy predictions found');
        return null;
      }
      
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final predictions = <int, Map<int, int>>{};
      
      jsonData.forEach((dayStr, hoursData) {
        final day = int.parse(dayStr);
        final hours = <int, int>{};
        
        (hoursData as Map<String, dynamic>).forEach((hourStr, energy) {
          hours[int.parse(hourStr)] = energy as int;
        });
        
        predictions[day] = hours;
      });
      
      _logger.info('Retrieved cached energy predictions for ${predictions.length} days');
      return predictions;
    } catch (e, stack) {
      _logger.severe('Error retrieving cached energy predictions', e, stack);
      return null;
    }
  }

  @override
  Future<void> clearWeeklyCache(DateTime weekStart) async {
    _logger.info('Clearing cache for week starting: $weekStart');
    
    try {
      final keys = [
        _getScheduleKey(weekStart),
        _getStatsKey(weekStart),
        _getEnergyKey(weekStart),
      ];
      
      for (final key in keys) {
        await _sharedPreferences.remove(key);
        await _sharedPreferences.remove(_getCacheTimestampKey(key));
      }
      
      _logger.fine('Weekly cache cleared successfully');
    } catch (e, stack) {
      _logger.severe('Error clearing weekly cache', e, stack);
      throw CacheException('Failed to clear weekly cache');
    }
  }

  @override
  Future<void> clearAllCache() async {
    _logger.info('Clearing all weekly planning cache');
    
    try {
      final keys = _sharedPreferences.getKeys();
      final weeklyKeys = keys.where((key) => 
        key.startsWith(_schedulePrefix) ||
        key.startsWith(_statsPrefix) ||
        key.startsWith(_energyPrefix) ||
        key.startsWith(_cacheTimestampPrefix)
      );
      
      for (final key in weeklyKeys) {
        await _sharedPreferences.remove(key);
      }
      
      _logger.info('Cleared ${weeklyKeys.length} cache entries');
    } catch (e, stack) {
      _logger.severe('Error clearing all cache', e, stack);
      throw CacheException('Failed to clear all cache');
    }
  }

  String _getScheduleKey(DateTime weekStart) {
    return '$_schedulePrefix${weekStart.toIso8601String()}';
  }

  String _getStatsKey(DateTime weekStart) {
    return '$_statsPrefix${weekStart.toIso8601String()}';
  }

  String _getEnergyKey(DateTime weekStart) {
    return '$_energyPrefix${weekStart.toIso8601String()}';
  }

  String _getCacheTimestampKey(String key) {
    return '$_cacheTimestampPrefix$key';
  }

  Future<void> _setCacheTimestamp(String key) async {
    final timestampKey = _getCacheTimestampKey(key);
    await _sharedPreferences.setInt(
      timestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _isCacheValid(String key) {
    final timestampKey = _getCacheTimestampKey(key);
    final timestamp = _sharedPreferences.getInt(timestampKey);
    
    if (timestamp == null) {
      return false;
    }
    
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    
    final isValid = difference < _cacheValidDuration;
    _logger.finest('Cache age: ${difference.inMinutes} minutes, valid: $isValid');
    
    return isValid;
  }
}