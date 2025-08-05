import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:school_fls/firebase/firebase_options.dart';
import 'package:school_fls/intro/intro.dart';
import 'package:school_fls/main_axis_pages/teachers/main_teachers.dart';
import 'package:school_fls/login_page/features/auth/cubit/auth_cubit.dart';
import 'package:school_fls/login_page/features/auth/data/auth_repository.dart';
import 'package:school_fls/login_page/auto_login_page.dart';
import 'package:school_fls/intro/select_role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (context) => AuthCubit(AuthRepository()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const IntroPage(),
        routes: {
          '/auto-login': (_) => const AutoLoginPage(),
          '/role-selection': (_) => const RoleSelectionPage(),
          '/teacher/home': (_) => const TeacherHomePage(),
          // Add other routes here later:
          // '/student/home': (_) => const StudentHomePage(),
          // '/parent/home': (_) => const ParentHomePage(),
          // '/admin/home': (_) => const AdminHomePage(),
        },
      ),
    );
  }
}
