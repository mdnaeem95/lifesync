class ServerException implements Exception {
  final String message;
  
  ServerException(this.message);
  
  @override
  String toString() => 'ServerException: $message';
}

class CacheException implements Exception {
  final String message;
  
  CacheException(this.message);
  
  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;
  
  NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = "Unauthorized"]);
  @override
  String toString() => "UnauthorizedException: $message";
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = "Not found"]);
  @override
  String toString() => "NotFoundException: $message";
}

class ConflictException implements Exception {
  final String message;
  ConflictException([this.message = "Conflict"]);
  @override
  String toString() => "ConflictException: $message";
}