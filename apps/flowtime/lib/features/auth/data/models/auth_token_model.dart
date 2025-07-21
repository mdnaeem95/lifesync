class AuthTokenModel {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  
  const AuthTokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    final expiresIn = json['expiresIn'] as int; // seconds
    return AuthTokenModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}