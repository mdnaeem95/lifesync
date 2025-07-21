import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? preferences;
  
  const User({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    required this.createdAt,
    this.preferences,
  });
  
  @override
  List<Object?> get props => [id, email, name, photoUrl, createdAt, preferences];
}