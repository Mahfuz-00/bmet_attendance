import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../Common/Config/Assets/app_images.dart';
import '../../Common/Config/Theme/app_colors.dart';
import '../../Core/Dependecy Injection/di.dart' as di;
import '../../Core/Navigation/app_router.dart';
import '../../Core/Widgets/custom_textfield.dart';
import '../../Domain/Entities/login_request.dart';
import '../../Presentation/Bloc/login_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<LoginBloc>(),
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: BlocConsumer<LoginBloc, LoginState>(
              listener: (context, state) {
                if (state is LoginSuccess) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.qrScanner,
                        (route) => false,
                  );
                } else if (state is LoginFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                }
              },
              builder: (context, state) {
                final isLoading = state is LoginLoading;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      AppImages.loginLogo,
                      height: 100,
                      width: 100,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image,
                        size: 100,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      isRequired: true,
                      readOnly: isLoading,
                    ),
                    const SizedBox(height: 16.0),
                    CustomTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      isRequired: true,
                      obscureText: true,
                      readOnly: isLoading,
                    ),
                    const SizedBox(height: 16.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Forgot Password not implemented')),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: AppColors.secondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                        context.read<LoginBloc>().add(
                          LoginSubmitted(
                            LoginRequest(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        minimumSize: const Size(double.infinity, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: AppColors.textPrimary)
                          : const Text(
                        'Login',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}