import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase
import 'viewmodels/user_viewmodel.dart';
import 'viewmodels/venting_viewmodel.dart';
import 'views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(); // Initialize Firebase
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Firebase 설정이 없어도 앱이 실행될 수 있도록 계속 진행합니다.
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => VentingViewModel()),
      ],
      child: const EmotionTokApp(),
    ),
  );
}

class EmotionTokApp extends StatelessWidget {
  const EmotionTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BURN IT: 감정쓰레기통',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFFF4D00),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D00),
          brightness: Brightness.dark,
          primary: const Color(0xFFFF4D00),
          secondary: const Color(0xFFFFD700),
        ),
        textTheme: GoogleFonts.notoSansTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
