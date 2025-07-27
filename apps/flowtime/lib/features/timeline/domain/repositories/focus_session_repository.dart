import '../entities/focus_session.dart';

abstract class FocusSessionRepository {
  Future<FocusSession> createSession(FocusSession session);
  Future<FocusSession> updateSession(FocusSession session);
  Future<void> deleteSession(String sessionId);
  Future<FocusSession?> getSession(String sessionId);
  Future<List<FocusSession>> getTodaySessions(String userId);
  Future<List<FocusSession>> getSessionsForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );
  Future<Map<String, dynamic>> getSessionStats(String userId, {int days = 7});
}