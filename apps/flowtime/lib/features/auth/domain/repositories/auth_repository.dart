import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  });
  
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  });
  
  Future<Either<Failure, User>> signInWithGoogle();
  
  Future<Either<Failure, User>> signInWithApple();
  
  Future<Either<Failure, bool>> signInWithBiometric();
  
  Future<Either<Failure, void>> signOut();
  
  Future<Either<Failure, User>> getCurrentUser();
  
  Stream<User?> get authStateChanges;
}