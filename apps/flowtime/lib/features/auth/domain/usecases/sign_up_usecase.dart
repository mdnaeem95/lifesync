import '../repositories/auth_repository.dart';

class SignUpParams {
  final String email;
  final String password;
  final String? name;

  SignUpParams({required this.email, required this.password, this.name});
}

class SignUpUseCase {
  final AuthRepository repository;

  SignUpUseCase(this.repository);

  Future call(SignUpParams params) {
    return repository.signUpWithEmail(
      email: params.email,
      password: params.password,
      name: params.name,
    );
  }
}