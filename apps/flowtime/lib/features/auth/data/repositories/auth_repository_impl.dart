import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({required this.remoteDataSource, required this.localDataSource});
  @override
  Future<Either<Failure, User>> signInWithEmail({required String email, required String password}) async {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, User>> signUpWithEmail({required String email, required String password, String? name}) async {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, bool>> signInWithBiometric() async {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Stream<User?> get authStateChanges => throw UnimplementedError();
}