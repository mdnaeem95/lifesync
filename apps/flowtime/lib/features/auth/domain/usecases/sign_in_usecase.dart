import '../repositories/auth_repository.dart';

class SignInParams {
  final String email;
  final String password;

  SignInParams({required this.email, required this.password});
}

class SignInUseCase {
  final AuthRepository repository;

  SignInUseCase(this.repository);

  Future call(SignInParams params) {
    return repository.signInWithEmail(
      email: params.email,
      password: params.password,
    );
  }
}