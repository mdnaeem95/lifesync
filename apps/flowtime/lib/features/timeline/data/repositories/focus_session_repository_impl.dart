import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/focus_session.dart';
import '../../domain/repositories/focus_session_repository.dart';

class FocusSessionRepositoryImpl implements FocusSessionRepository {
  final _supabase = Supabase.instance.client;
  
  @override
  Future<FocusSession> createSession(FocusSession session) async {
    final data = session.toJson();
    data.remove('id'); // Let Supabase generate the ID
    
    final response = await _supabase
        .from('flowtime_focus_sessions')
        .insert(data)
        .select()
        .single();
        
    return FocusSession.fromJson(response);
  }
  
  @override
  Future<FocusSession> updateSession(FocusSession session) async {
    final response = await _supabase
        .from('flowtime_focus_sessions')
        .update(session.toJson())
        .eq('id', session.id)
        .select()
        .single();
        
    return FocusSession.fromJson(response);
  }
  
  @override
  Future<void> deleteSession(String sessionId) async {
    await _supabase
        .from('flowtime_focus_sessions')
        .delete()
        .eq('id', sessionId);
  }
  
  @override
  Future<FocusSession?> getSession(String sessionId) async {
    final response = await _supabase
        .from('flowtime_focus_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
        
    return response != null ? FocusSession.fromJson(response) : null;
  }
  
  @override
  Future<List<FocusSession>> getTodaySessions(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final response = await _supabase
        .from('flowtime_focus_sessions')
        .select()
        .eq('user_id', userId)
        .gte('started_at', startOfDay.toIso8601String())
        .lt('started_at', endOfDay.toIso8601String())
        .order('started_at', ascending: false);
        
    return (response as List)
        .map((json) => FocusSession.fromJson(json))
        .toList();
  }
  
  @override
  Future<List<FocusSession>> getSessionsForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _supabase
        .from('flowtime_focus_sessions')
        .select()
        .eq('user_id', userId)
        .gte('started_at', startDate.toIso8601String())
        .lte('started_at', endDate.toIso8601String())
        .order('started_at', ascending: false);
        
    return (response as List)
        .map((json) => FocusSession.fromJson(json))
        .toList();
  }
  
  @override
  Future<Map<String, dynamic>> getSessionStats(String userId, {int days = 7}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    
    final sessions = await getSessionsForDateRange(userId, startDate, endDate);
    
    // Calculate stats
    int totalMinutes = 0;
    int totalSessions = sessions.length;
    int completedSessions = 0;
    int totalInterruptions = 0;
    Map<String, int> protocolCounts = {};
    
    for (final session in sessions) {
      if (session.actualDuration != null) {
        totalMinutes += session.actualDuration!.inMinutes;
        completedSessions++;
      }
      totalInterruptions += session.interruptions;
      
      final protocol = session.focusProtocol.name;
      protocolCounts[protocol] = (protocolCounts[protocol] ?? 0) + 1;
    }
    
    // Calculate streak
    int currentStreak = 0;
    DateTime checkDate = DateTime.now();
    
    while (currentStreak < days) {
      final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      
      final daySessions = sessions.where((s) => 
        s.startedAt.isAfter(dayStart) && s.startedAt.isBefore(dayEnd)
      ).toList();
      
      if (daySessions.isEmpty) break;
      
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return {
      'totalMinutes': totalMinutes,
      'totalSessions': totalSessions,
      'completedSessions': completedSessions,
      'totalInterruptions': totalInterruptions,
      'averageSessionLength': totalSessions > 0 ? totalMinutes ~/ totalSessions : 0,
      'completionRate': totalSessions > 0 ? (completedSessions / totalSessions * 100).round() : 0,
      'currentStreak': currentStreak,
      'protocolCounts': protocolCounts,
      'mostUsedProtocol': protocolCounts.isEmpty ? null : 
          protocolCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }
}