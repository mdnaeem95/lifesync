class ApiEndpoints {
  // Base URL without /api suffix since services handle their own paths
  static const String baseUrl = 'http://localhost:8000';
  
  // Auth endpoints (auth service)
  static const String signIn = '/auth/signin';
  static const String signUp = '/auth/signup';
  static const String signOut = '/auth/signout';
  static const String refreshToken = '/auth/refresh';
  
  // FlowTime endpoints (flowtime service)
  static const String tasks = '/api/flowtime/tasks';
  static const String energy = '/api/flowtime/energy';
  static const String energyCurrent = '/api/flowtime/energy/current';
  static const String focusSessions = '/api/flowtime/sessions';
  static const String suggestedTimeSlots = '/api/flowtime/tasks/suggest-slots';
  static const String preferences = '/api/flowtime/preferences';
  static const String dailyStats = '/api/flowtime/stats/daily';
}