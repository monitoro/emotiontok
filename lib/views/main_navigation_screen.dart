import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../viewmodels/user_viewmodel.dart';
import 'home_screen.dart';
import 'square_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  int _actualIndex = 1000; // Large number for infinite-like scrolling
  late AudioPlayer _bgmPlayer;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SquareScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _actualIndex);
    _bgmPlayer = AudioPlayer();
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);

    // Initial check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBgmState();

      // Listen to settings changes
      final userVM = Provider.of<UserViewModel>(context, listen: false);
      userVM.addListener(_onUserVmChanged);
    });
  }

  void _onUserVmChanged() {
    if (mounted) _checkBgmState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final userVM = Provider.of<UserViewModel>(context, listen: false);
    userVM.removeListener(_onUserVmChanged);
    _pageController.dispose();
    _bgmPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _bgmPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      _checkBgmState();
    }
  }

  Future<void> _checkBgmState() async {
    if (!mounted) return;
    final userVM = Provider.of<UserViewModel>(context, listen: false);
    final isHome = (_actualIndex % _screens.length) == 0;

    if (userVM.isBgmOn && isHome) {
      if (_bgmPlayer.state != PlayerState.playing) {
        try {
          await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'), volume: 0.3);
        } catch (e) {
          debugPrint('BGM error: $e');
        }
      }
    } else {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
    }
  }

  int get _selectedIndex => _actualIndex % _screens.length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        final bool shouldExit = await _showExitDialog() ?? false;
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _actualIndex = index;
            });
            _checkBgmState(); // Check BGM on page change
          },
          itemBuilder: (context, index) {
            return _screens[index % _screens.length];
          },
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border:
                Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              // Find the closest index to the current one that matches the target tab
              int currentModulo = _actualIndex % _screens.length;
              int difference = index - currentModulo;
              _pageController.animateToPage(
                _actualIndex + difference,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFFFF4D00),
            unselectedItemColor: Colors.grey,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: '홈'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.fireplace_outlined),
                  activeIcon: Icon(Icons.fireplace),
                  label: '광장'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: '보관함'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: '설정'),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('앱 종료', style: TextStyle(color: Colors.white)),
        content: const Text('마음을 그만 태우고 종료하시겠습니까?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니요', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('네, 종료합니다',
                style: TextStyle(color: Color(0xFFFF4D00))),
          ),
        ],
      ),
    );
  }
}
