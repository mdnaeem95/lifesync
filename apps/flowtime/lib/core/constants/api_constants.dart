/// Central location for all API-related constants
class ApiConstants {
  ApiConstants._();
  
  // Base URLs
  static const String productionBaseUrl = 'https://api.flowtime.app';
  static const String stagingBaseUrl = 'https://staging-api.flowtime.app';
  static const String developmentBaseUrl = 'http://localhost:8000';
  
  // Current environment - this should be set based on build configuration
  static const String baseUrl = developmentBaseUrl;
  
  // API Version
  static const String apiVersion = '/api/v1';
  
  // Full API URL
  static const String apiUrl = '$baseUrl$apiVersion';
  
  // Authentication endpoints
  static const String authEndpoint = '$apiUrl/auth';
  static const String signInEndpoint = '$authEndpoint/signin';
  static const String signUpEndpoint = '$authEndpoint/signup';
  static const String signOutEndpoint = '$authEndpoint/signout';
  static const String refreshTokenEndpoint = '$authEndpoint/refresh';
  static const String verifyEmailEndpoint = '$authEndpoint/verify-email';
  static const String resetPasswordEndpoint = '$authEndpoint/reset-password';
  static const String changePasswordEndpoint = '$authEndpoint/change-password';
  
  // User endpoints
  static const String usersEndpoint = '$apiUrl/users';
  static const String currentUserEndpoint = '$usersEndpoint/me';
  static const String updateProfileEndpoint = '$usersEndpoint/me';
  static const String uploadAvatarEndpoint = '$usersEndpoint/me/avatar';
  static const String userPreferencesEndpoint = '$usersEndpoint/me/preferences';
  
  // FlowTime specific endpoints
  static const String flowtimeEndpoint = '$apiUrl/flowtime';
  static const String tasksEndpoint = '$flowtimeEndpoint/tasks';
  static const String energyEndpoint = '$flowtimeEndpoint/energy';
  static const String focusSessionsEndpoint = '$flowtimeEndpoint/focus-sessions';
  static const String weeklyPlanningEndpoint = '$flowtimeEndpoint/weekly-planning';
  static const String analyticsEndpoint = '$flowtimeEndpoint/analytics';
  
  // Task endpoints
  static const String createTaskEndpoint = tasksEndpoint;
  static const String updateTaskEndpoint = '$tasksEndpoint/:id';
  static const String deleteTaskEndpoint = '$tasksEndpoint/:id';
  static const String completeTaskEndpoint = '$tasksEndpoint/:id/complete';
  static const String uncompleteTaskEndpoint = '$tasksEndpoint/:id/uncomplete';
  static const String suggestSlotsEndpoint = '$tasksEndpoint/suggest-slots';
  
  // Energy endpoints
  static const String currentEnergyEndpoint = '$energyEndpoint/current';
  static const String energyHistoryEndpoint = '$energyEndpoint/history';
  static const String energyPredictionsEndpoint = '$energyEndpoint/predictions';
  static const String updateEnergyEndpoint = '$energyEndpoint/update';
  
  // Focus session endpoints
  static const String startFocusEndpoint = '$focusSessionsEndpoint/start';
  static const String pauseFocusEndpoint = '$focusSessionsEndpoint/:id/pause';
  static const String resumeFocusEndpoint = '$focusSessionsEndpoint/:id/resume';
  static const String endFocusEndpoint = '$focusSessionsEndpoint/:id/end';
  static const String focusHistoryEndpoint = '$focusSessionsEndpoint/history';
  
  // Weekly planning endpoints
  static const String weeklyScheduleEndpoint = '$weeklyPlanningEndpoint/schedule';
  static const String optimizeScheduleEndpoint = '$weeklyPlanningEndpoint/optimize';
  static const String batchRescheduleEndpoint = '$weeklyPlanningEndpoint/batch-reschedule';
  static const String weeklyStatsEndpoint = '$weeklyPlanningEndpoint/stats';
  
  // Analytics endpoints
  static const String productivityMetricsEndpoint = '$analyticsEndpoint/productivity';
  static const String energyPatternsEndpoint = '$analyticsEndpoint/energy-patterns';
  static const String insightsEndpoint = '$analyticsEndpoint/insights';
  static const String exportDataEndpoint = '$analyticsEndpoint/export';
  
  // Notification endpoints
  static const String notificationsEndpoint = '$apiUrl/notifications';
  static const String registerDeviceEndpoint = '$notificationsEndpoint/devices';
  static const String notificationSettingsEndpoint = '$notificationsEndpoint/settings';
  
  // Integration endpoints
  static const String integrationsEndpoint = '$apiUrl/integrations';
  static const String googleCalendarEndpoint = '$integrationsEndpoint/google-calendar';
  static const String appleHealthEndpoint = '$integrationsEndpoint/apple-health';
  static const String fitbitEndpoint = '$integrationsEndpoint/fitbit';
  
  // WebSocket endpoints
  static final String wsBaseUrl = baseUrl.replaceFirst('http', 'ws');
  static final String wsUrl = '$wsBaseUrl/ws';
  static final String realtimeUpdatesEndpoint = '$wsUrl/updates';
  
  // HTTP Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Timeouts (in seconds)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Cache durations (in minutes)
  static const int shortCacheDuration = 5;
  static const int mediumCacheDuration = 30;
  static const int longCacheDuration = 120;
  
  // API Keys (these should be stored securely in production)
  static const String apiKey = 'YOUR_API_KEY_HERE';
  static const String googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE';
  
  // Feature flags endpoints
  static const String featureFlagsEndpoint = '$apiUrl/feature-flags';
  
  // Health check
  static const String healthCheckEndpoint = '$baseUrl/health';
  
  // Helper methods
  static String buildTaskEndpoint(String taskId) {
    return '$tasksEndpoint/$taskId';
  }
  
  static String buildFocusSessionEndpoint(String sessionId, String action) {
    return '$focusSessionsEndpoint/$sessionId/$action';
  }
  
  static String buildUserEndpoint(String userId) {
    return '$usersEndpoint/$userId';
  }
  
  static Map<String, String> getAuthHeaders(String token) {
    return {
      ...defaultHeaders,
      'Authorization': 'Bearer $token',
    };
  }
  
  static Map<String, dynamic> getPaginationParams({
    int page = 1,
    int pageSize = defaultPageSize,
    String? sortBy,
    bool ascending = true,
  }) {
    return {
      'page': page,
      'page_size': pageSize.clamp(1, maxPageSize),
      if (sortBy != null) 'sort_by': sortBy,
      'ascending': ascending,
    };
  }
}