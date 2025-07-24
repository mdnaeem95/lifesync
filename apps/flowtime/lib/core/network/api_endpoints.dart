class ApiEndpoints {
  static const String baseUrl = 'http://localhost:8000/api';
  
  // Auth endpoints
  static const String signIn = '/auth/signin';
  static const String signUp = '/auth/signup';
  static const String signOut = '/auth/signout';
  static const String refreshToken = '/auth/refresh';
  
  // FlowTime endpoints
  static const String tasks = '/flowtime/tasks';
  static const String energy = '/flowtime/energy';
  static const String energyCurrent = '/flowtime/energy/current';
  static const String focusSessions = '/flowtime/sessions';
  static const String suggestedTimeSlots = '/flowtime/tasks/suggest-slots';
  static const String preferences = '/flowtime/preferences';
  static const String dailyStats = '/flowtime/stats/daily';
}