import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Common/Config/Theme/app_colors.dart';
import 'Core/Dependecy Injection/di.dart' as di;
import 'Core/Navigation/app_router.dart';
import 'Data/Repositories/login_repository_imp.dart';
import 'Data/Source/API/login_api_service.dart';
import 'Domain/Repositories/auth_repository.dart';
import 'Domain/Usecases/login.dart';
import 'Presentation/Bloc/attendance_data_bloc.dart';
import 'Presentation/Bloc/face_recognition_bloc.dart';
import 'Presentation/Bloc/geolocation_bloc.dart';
import 'Presentation/Bloc/login_bloc.dart';
import 'Presentation/Bloc/registration_bloc.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      print('Main: Bypassing SSL verification for host: $host, port: $port');
      return true; // Allow untrusted certificates
    };
    return client;
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  print('Main: GetIt instance: ${di.sl.hashCode}');
  print('LoginBloc registered by ME? ${di.sl.isRegistered<LoginBloc>()}');
  print('LoginBloc registered by You? ${di.sl.isRegistered<LoginBloc>(instance: false)}');
  print('Login usecase registered? ${di.sl.isRegistered<Login>(instance: false)}');
  print('AuthRepository registered? ${di.sl.isRegistered<AuthRepository>(instance: false)}');
  print('AttendanceBloc registered? ${di.sl.isRegistered<AttendanceDataBloc>()}');
  print('RegisterBloc registered? ${di.sl.isRegistered<RegistrationBloc>()}');


  // Fallback registrations
  if (!di.sl.isRegistered<AuthRepository>()) {
    final prefs = await SharedPreferences.getInstance();
    di.sl.registerSingleton<SharedPreferences>(prefs);
    di.sl.registerLazySingleton<AuthRepository>(
          () => AuthRepositoryImpl(
        apiService: di.sl<LoginApiService>(),
        prefs: di.sl<SharedPreferences>(),
      ),
    );
    print('Main: AuthRepository manually registered');
  }
  if (!di.sl.isRegistered<Login>()) {
    di.sl.registerLazySingleton<Login>(() => Login(di.sl<AuthRepository>()));
    print('Main: Login usecase manually registered');
  }
  if (!di.sl.isRegistered<LoginBloc>()) {
    di.sl.registerFactory<LoginBloc>(() => LoginBloc(login: di.sl<Login>()));
    print('Main: LoginBloc manually registered');
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<LoginBloc>(create: (_) => di.sl<LoginBloc>()),
        BlocProvider<AttendanceDataBloc>(create: (_) => di.sl<AttendanceDataBloc>()),
        BlocProvider<RegistrationBloc>(create: (_) => di.sl<RegistrationBloc>()),
        BlocProvider<FaceRecognitionBloc>(create: (_) => di.sl<FaceRecognitionBloc>()),
        BlocProvider<GeolocationBloc>(create: (_) => di.sl<GeolocationBloc>()),
      ],
      child: const TouchAttendanceApp(),
    ),
  );
}

class TouchAttendanceApp extends StatelessWidget {
  const TouchAttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('LoginBloc resolved? ${BlocProvider.of<LoginBloc>(context) != null}');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Touch Attendance',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splashScreen,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
