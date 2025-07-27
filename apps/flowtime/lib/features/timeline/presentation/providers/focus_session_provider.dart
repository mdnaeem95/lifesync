import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../domain/entities/focus_session.dart';
import '../../domain/repositories/focus_session_repository.dart';
import '../../data/repositories/focus_session_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Focus session state
class FocusSessionState {
  final FocusSession? activeSession;
  final List<FocusSession> todaySessions;
  final bool isLoading;
  final String? error;
  final int totalFocusTime; // in minutes
  final int interruptions;
  
  const FocusSessionState({
    this.activeSession,
    this.todaySessions = const [],
    this.isLoading = false,
    this.error,
    this.totalFocusTime = 0,
    this.interruptions = 0,
  });
  
  FocusSessionState copyWith({
    FocusSession? activeSession,
    List<FocusSession>? todaySessions,
    bool? isLoading,
    String? error,
    int? totalFocusTime,
    int? interruptions,
  }) {
    return FocusSessionState(
      activeSession: activeSession ?? this.activeSession,
      todaySessions: todaySessions ?? this.todaySessions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      totalFocusTime: totalFocusTime ?? this.totalFocusTime,
      interruptions: interruptions ?? this.interruptions,
    );
  }
}

// Repository provider
final focusSessionRepositoryProvider = Provider<FocusSessionRepository>((ref) {
  return FocusSessionRepositoryImpl();
});

// Focus session notifier
class FocusSessionNotifier extends StateNotifier<FocusSessionState> {
  final FocusSessionRepository _repository;
  final Ref _ref;
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  
  FocusSessionNotifier(this._repository, this._ref) 
      : super(const FocusSessionState()) {
    loadTodaySessions();
  }
  
  Future<void> loadTodaySessions() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final authState = _ref.read(authNotifierProvider);
      final user = authState.valueOrNull;
      if (user == null) return;
      
      final sessions = await _repository.getTodaySessions(user.id);
      final totalTime = sessions.fold<int>(
        0, 
        (sum, session) => sum + (session.actualDuration?.inMinutes ?? 0),
      );
      
      state = state.copyWith(
        todaySessions: sessions,
        totalFocusTime: totalTime,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
  
  Future<void> startSession({
    String? taskId,
    required Duration duration,
    required FocusProtocol protocol,
    int? energyLevelStart,
  }) async {
    final authState = _ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    if (user == null) return;
    
    _sessionStartTime = DateTime.now();
    
    final session = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id,
      taskId: taskId,
      startedAt: _sessionStartTime!,
      plannedDuration: duration,
      focusProtocol: protocol,
      energyLevelStart: energyLevelStart,
      interruptions: 0,
    );
    
    state = state.copyWith(activeSession: session);
    
    // Start session timer
    _startSessionTimer();
    
    try {
      await _repository.createSession(session);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  void pauseSession() {
    _sessionTimer?.cancel();
    if (state.activeSession != null) {
      state = state.copyWith(
        activeSession: state.activeSession!.copyWith(
          isPaused: true,
        ),
      );
    }
  }
  
  void resumeSession() {
    if (state.activeSession != null) {
      state = state.copyWith(
        activeSession: state.activeSession!.copyWith(
          isPaused: false,
        ),
      );
      _startSessionTimer();
    }
  }
  
  void recordInterruption() {
    if (state.activeSession != null) {
      final updatedSession = state.activeSession!.copyWith(
        interruptions: state.activeSession!.interruptions + 1,
      );
      state = state.copyWith(
        activeSession: updatedSession,
        interruptions: state.interruptions + 1,
      );
    }
  }
  
  Future<void> endSession({int? energyLevelEnd}) async {
    _sessionTimer?.cancel();
    
    if (state.activeSession == null || _sessionStartTime == null) return;
    
    final endedAt = DateTime.now();
    final actualDuration = endedAt.difference(_sessionStartTime!);
    
    final completedSession = state.activeSession!.copyWith(
      endedAt: endedAt,
      actualDuration: actualDuration,
      energyLevelEnd: energyLevelEnd,
    );
    
    try {
      await _repository.updateSession(completedSession);
      
      // Reload today's sessions
      await loadTodaySessions();
      
      state = state.copyWith(activeSession: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> completeSession({int? energyLevelEnd}) async {
    await endSession(energyLevelEnd: energyLevelEnd);
  }
  
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.activeSession != null && !state.activeSession!.isPaused) {
        // Update session progress
        final elapsed = DateTime.now().difference(_sessionStartTime!);
        if (elapsed >= state.activeSession!.plannedDuration) {
          completeSession();
        }
      }
    });
  }
  
  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}

// Provider
final focusSessionProvider = StateNotifierProvider<FocusSessionNotifier, FocusSessionState>((ref) {
  final repository = ref.watch(focusSessionRepositoryProvider);
  return FocusSessionNotifier(repository, ref);
});

// Enum extensions
enum FocusProtocol {
  pomodoro,
  timeboxing,
  deepWork,
  custom,
}

extension FocusProtocolExtension on FocusProtocol {
  String get displayName {
    switch (this) {
      case FocusProtocol.pomodoro:
        return 'Pomodoro';
      case FocusProtocol.timeboxing:
        return 'Time Boxing';
      case FocusProtocol.deepWork:
        return 'Deep Work';
      case FocusProtocol.custom:
        return 'Custom';
    }
  }
  
  Duration get defaultDuration {
    switch (this) {
      case FocusProtocol.pomodoro:
        return const Duration(minutes: 25);
      case FocusProtocol.timeboxing:
        return const Duration(minutes: 45);
      case FocusProtocol.deepWork:
        return const Duration(minutes: 90);
      case FocusProtocol.custom:
        return const Duration(minutes: 30);
    }
  }
  
  String get description {
    switch (this) {
      case FocusProtocol.pomodoro:
        return '25 min focus, 5 min break';
      case FocusProtocol.timeboxing:
        return '45 min dedicated blocks';
      case FocusProtocol.deepWork:
        return '90 min deep concentration';
      case FocusProtocol.custom:
        return 'Set your own duration';
    }
  }
}