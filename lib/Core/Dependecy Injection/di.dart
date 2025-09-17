import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Data/Repositories/attendance_repository_impl.dart';
import '../../Data/Repositories/face_recognition_repository_impl.dart';
import '../../Data/Repositories/geolocation_repository_impl.dart';
import '../../Data/Repositories/login_repository_imp.dart';
import '../../Data/Source/API/login_api_service.dart';
import '../../Data/Source/API/registration_api_service.dart';
import '../../Data/Source/API/face_embedding_api_service.dart';
import '../../Data/Source/API/attendance_submission_api_service.dart';
import '../../Data/Source/API/face_recognition_service.dart';
import '../../Domain/Repositories/attendance_repository.dart';
import '../../Domain/Repositories/face_recognition_repository.dart';
import '../../Domain/Repositories/geolocation_repository.dart';
import '../../Domain/Repositories/auth_repository.dart';
import '../../Domain/Usecases/check_registration.dart';
import '../../Domain/Usecases/fetch_face_embedding.dart';
import '../../Domain/Usecases/submit_attendance.dart';
import '../../Domain/Usecases/capture_face.dart';
import '../../Domain/Usecases/verify_face.dart';
import '../../Domain/Usecases/get_location.dart';
import '../../Domain/Usecases/login.dart';
import '../../Presentation/Bloc/attendance_data_bloc.dart';
import '../../Presentation/Bloc/registration_bloc.dart' hide CheckRegistration;
import '../../Presentation/Bloc/face_recognition_bloc.dart';
import '../../Presentation/Bloc/geolocation_bloc.dart';
import '../../presentation/Bloc/login_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Services
  sl.registerLazySingleton(() => RegistrationApiService());
  sl.registerLazySingleton(() => FaceEmbeddingApiService());
  sl.registerLazySingleton(() => AttendanceSubmissionApiService());
  sl.registerLazySingleton(() => FaceRecognitionService());
  sl.registerLazySingleton(() => LoginApiService());

  // SharedPreferences
  sl.registerSingletonAsync<SharedPreferences>(() => SharedPreferences.getInstance());

  // Repositories
  sl.registerLazySingleton<AttendanceRepository>(
        () => AttendanceRepositoryImpl(
      registrationApiService: sl(),
      attendanceSubmissionApiService: sl(),
    ),
  );
  sl.registerLazySingleton<FaceRecognitionRepository>(
        () => FaceRecognitionRepositoryImpl(
      service: sl(),
      faceEmbeddingApiService: sl(),
    ),
  );
  sl.registerLazySingleton<GeolocationRepository>(
        () => GeolocationRepositoryImpl(),
  );
  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(
      apiService: sl(),
      prefs: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => CheckRegistration(sl()));
  sl.registerLazySingleton(() => FetchFaceEmbedding(sl()));
  sl.registerLazySingleton(() => SubmitAttendance(sl()));
  sl.registerLazySingleton(() => CaptureFace(sl()));
  sl.registerLazySingleton(() => VerifyFaceUseCase(sl()));
  sl.registerLazySingleton(() => GetLocation(sl()));
  sl.registerLazySingleton(() => Login(sl()));

  // BLoCs
  sl.registerFactory(() => AttendanceDataBloc());
  sl.registerFactory(() => RegistrationBloc(checkRegistration: sl()));
  sl.registerFactory(() => FaceRecognitionBloc(
    captureFace: sl(),
    fetchFaceEmbedding: sl(),
    verifyFace: sl<VerifyFaceUseCase>(),
  ));
  sl.registerFactory(() => GeolocationBloc(getLocation: sl()));
  sl.registerFactory(() => LoginBloc(login: sl()));
}