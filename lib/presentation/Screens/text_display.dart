import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../Core/Dependecy Injection/di.dart';
import '../../Core/Navigation/app_router.dart';
import '../Bloc/attendance_data_bloc.dart';
import '../Bloc/registration_bloc.dart';
import '../Widgets/profile_image_widget.dart';
import '../Widgets/field_list_widget.dart';
import '../Widgets/action_button_widget.dart';

class TextDisplayScreen extends StatelessWidget {
  const TextDisplayScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, AppRoutes.qrScanner);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Information'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.qrScanner);
            },
          ),
        ),
        body: BlocListener<RegistrationBloc, RegistrationState>(
          listener: (context, state) {
            if (state is RegistrationError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            } else if (state is RegistrationLoaded) {
              Navigator.pushNamed(context, AppRoutes.attendancePhoto);
            }
          },
          child: BlocBuilder<AttendanceDataBloc, AttendanceDataState>(
            builder: (context, state) {
              if (state is AttendanceDataInitial) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No data found. Please scan a valid QR code.')),
                  );
                  Navigator.pushReplacementNamed(context, AppRoutes.qrScanner);
                });
                return const Center(child: CircularProgressIndicator());
              } else if (state is AttendanceDataLoaded) {
                final student = state.student;
                final filteredEntries = student.fields.entries
                    .where((entry) =>
                entry.value != null &&
                    entry.value!.isNotEmpty &&
                    entry.value != 'Not found')
                    .toList();

                final uniqueEntriesMap = <String, String>{};
                for (var entry in filteredEntries) {
                  if (!uniqueEntriesMap.containsKey(entry.key)) {
                    uniqueEntriesMap[entry.key] = entry.value!;
                  }
                }

                final nameTypeSubstrings = ['name', "father's", "mother's"];
                final idTypeSubstrings = ['no', 'id', 'code', 'destination country'];
                final venueCourseType = ['venue', 'course'];

                bool containsAny(String key, List<String> substrings) {
                  final lowerKey = key.toLowerCase();
                  return substrings.any((sub) => lowerKey.contains(sub));
                }

                final sortedKeys = [
                  ...uniqueEntriesMap.keys.where((k) => containsAny(k, nameTypeSubstrings)),
                  ...uniqueEntriesMap.keys.where((k) =>
                  !containsAny(k, nameTypeSubstrings) &&
                      containsAny(k, idTypeSubstrings)),
                  ...uniqueEntriesMap.keys.where((k) =>
                  !containsAny(k, nameTypeSubstrings) &&
                      !containsAny(k, idTypeSubstrings) &&
                      containsAny(k, venueCourseType)),
                  ...uniqueEntriesMap.keys.where((k) =>
                  !containsAny(k, nameTypeSubstrings) &&
                      !containsAny(k, idTypeSubstrings) &&
                      !containsAny(k, venueCourseType)),
                ];

                final validFields = sortedKeys
                    .map((key) => MapEntry(key, uniqueEntriesMap[key]!))
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProfileImageWidget(
                        profileImages: student.profileImages,
                        width: screenWidth,
                      ),
                      FieldListWidget(fields: validFields),
                      const SizedBox(height: 24),
                      BlocBuilder<RegistrationBloc, RegistrationState>(
                        builder: (context, regState) {
                          return ActionButtonWidget(
                            label: 'Check Registration',
                            icon: Icons.person_search,
                            isLoading: regState is RegistrationLoading,
                            onPressed: () {
                              final studentId = student.fields['Student ID'] ?? 'Not found';
                              if (studentId == 'Not found') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Student ID not found')),
                                );
                                return;
                              }
                              context.read<RegistrationBloc>().add(CheckRegistrationEvent(studentId));
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}