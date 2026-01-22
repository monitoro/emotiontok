import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/user_viewmodel.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final userVM = Provider.of<UserViewModel>(context, listen: false);

    // Run wait time and data loading in parallel
    await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      userVM.loadUserData(),
    ]);

    if (!mounted) return;

    // Auto-login check
    if (userVM.nickname != null) {
      bool authenticated = true;
      if (userVM.isBiometricEnabled) {
        authenticated = await userVM.authenticate();
      }

      if (authenticated) {
        userVM.login(); // Set valid session state
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        // Auth failed or canceled
        // For now, we can show a retry dialog or just exit.
        // Let's show a simple dialog and navigate to onboarding or exit?
        // Actually, just staying on splash might be stuck.
        // Let's Retry.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('생체 인증에 실패했습니다. 앱을 재실행해주세요.')),
          );
        }
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Placeholder for Logo/Animation
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF4D00),
                      const Color(0xFFFF4D00).withOpacity(0),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'BURN IT',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: const Color(0xFFFF4D00),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '감정 쓰레기통',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 2,
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
