import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:audioplayers/audioplayers.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../widgets/burning_animation.dart';
import '../widgets/doodle_view.dart';
import '../widgets/point_display.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  double _angerLevel = 0.0;
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isPressing = false;
  late AnimationController _pulseController;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.red,
    exportBackgroundColor: Colors.transparent,
  );

  late AudioPlayer _bgmPlayer;
  late AudioPlayer _sfxPlayer;

  @override
  void initState() {
    super.initState();
    _bgmPlayer = AudioPlayer();
    _sfxPlayer = AudioPlayer();
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);

    // Play BGM if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userVM = Provider.of<UserViewModel>(context, listen: false);
      _updateBgmState(userVM.isBgmOn);

      // Listen to settings changes
      userVM.addListener(() {
        if (!mounted) return;
        _updateBgmState(userVM.isBgmOn);
      });
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        if (_isPressing) {
          setState(() {
            _angerLevel = _pulseController.value * 100;
          });
        }
      });
  }

  @override
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  void _updateBgmState(bool isBgmOn) async {
    if (isBgmOn) {
      if (_bgmPlayer.state != PlayerState.playing) {
        // Assuming bgm.mp3 exists in assets/sounds/
        try {
          await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'), volume: 0.3);
        } catch (e) {
          debugPrint('BGM play failed: $e');
        }
      }
    } else {
      await _bgmPlayer.stop();
    }
  }

  void _startPressing() {
    setState(() => _isPressing = true);
    _pulseController.forward();
  }

  void _stopPressing() {
    setState(() => _isPressing = false);
    _pulseController.reset();
  }

  Future<void> _pickImage(VentingViewModel viewModel) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      viewModel.setPickedImagePath(image.path);
    }
  }

  void _burnEmotions(String text) {
    if (text.isEmpty && _signatureController.isEmpty) return;

    final ventingVM = Provider.of<VentingViewModel>(context, listen: false);
    final userVM = Provider.of<UserViewModel>(context, listen: false);

    // 1. Start burning animation
    // 1. Start burning animation
    ventingVM.startBurning();

    // Play burning SFX if enabled
    if (userVM.isSfxOn) {
      try {
        _sfxPlayer.play(AssetSource('sounds/explosion.mp3'));
      } catch (e) {
        debugPrint('SFX play failed: $e');
      }
    }

    // 2. Show burning dialog overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BurningAnimation(
        text: text,
        onComplete: () {
          Navigator.of(context).pop(); // Close dialog
          // 3. Save post and process
          ventingVM.finishBurning(
            userVM.selectedPersona,
            text,
            userVM,
            angerLevel: _angerLevel,
          );

          _textController.clear();
          _signatureController.clear();
          setState(() => _angerLevel = 0);

          // Show AI response dialog
          _showAiResponseDialog(context, ventingVM);
        },
      ),
    );
  }

  void _showAiResponseDialog(BuildContext context, VentingViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFFF4D00)),
              SizedBox(width: 8),
              Text('AI의 위로', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Consumer<VentingViewModel>(
            builder: (context, vm, child) {
              if (vm.lastAiResponse == null) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFF4D00)),
                    SizedBox(height: 16),
                    Text('감정을 분석하고 위로를 준비 중입니다...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                );
              }
              return Text(
                vm.lastAiResponse!,
                style: const TextStyle(color: Colors.white, height: 1.5),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                vm.clearAiResponse();
                Navigator.pop(context);
              },
              child: const Text('닫기', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ventingVM = Provider.of<VentingViewModel>(context);
    final userVM = Provider.of<UserViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('안녕하세요, ${userVM.nickname}님',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text('Lv.${userVM.level}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFFF4D00))),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: userVM.expProgress / 5,
                      backgroundColor: Colors.grey[800],
                      color: const Color(0xFFFF4D00),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        actions: [
          const PointDisplay(),
          const SizedBox(width: 8),
          Row(
            children: [
              Text(
                ventingVM.shareToSquare ? '광장에 공유' : '나만 보기',
                style: TextStyle(
                  color: ventingVM.shareToSquare
                      ? const Color(0xFFFF4D00)
                      : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: ventingVM.shareToSquare,
                activeColor: const Color(0xFFFF4D00),
                onChanged: (value) {
                  ventingVM.setShareToSquare(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value ? '광장에 공유됩니다' : '나만 봅니다'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input Area
                Container(
                  height: 300, // Increased height for input area
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPressing
                          ? Colors.red.withOpacity(_angerLevel / 100)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ventingVM.currentMode == VentingMode.text
                      ? TextField(
                          controller: _textController,
                          maxLines: null,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '지금 무슨 일이 있었나요? 속 시원하게 털어놓으세요...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        )
                      : DoodleView(controller: _signatureController),
                ),

                const SizedBox(height: 16),

                // Image Preview if picked
                if (ventingVM.pickedImagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(ventingVM.pickedImagePath!,
                                  height: 100)
                              : Image.file(File(ventingVM.pickedImagePath!),
                                  height: 100),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => ventingVM.setPickedImagePath(null),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tools Row
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.text_fields,
                          color: ventingVM.currentMode == VentingMode.text
                              ? const Color(0xFFFF4D00)
                              : Colors.grey),
                      onPressed: () => ventingVM.setMode(VentingMode.text),
                    ),
                    IconButton(
                      icon: Icon(Icons.brush,
                          color: ventingVM.currentMode == VentingMode.doodle
                              ? const Color(0xFFFF4D00)
                              : Colors.grey),
                      onPressed: () => ventingVM.setMode(VentingMode.doodle),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.grey),
                      onPressed: () => _pickImage(ventingVM),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Burn Button (Keep Pressing Interaction)
                Center(
                  child: GestureDetector(
                    onLongPressStart: (_) => _startPressing(),
                    onLongPressEnd: (_) {
                      _stopPressing();
                      if (_angerLevel >= 80) {
                        // Trigger only if anger level is high enough
                        if (ventingVM.shareToSquare) {
                          final error =
                              ventingVM.validateContent(_textController.text);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(error),
                                backgroundColor: Colors.red));
                            return;
                          }
                        }
                        _burnEmotions(_textController.text);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('감정을 더 모아서 꾹 눌러주세요! (80% 이상)')),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 120 + (_angerLevel * 0.5),
                      height: 120 + (_angerLevel * 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF4D00).withOpacity(0.8),
                            const Color(0xFFFF4D00).withOpacity(0.2),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4D00).withOpacity(0.5),
                            blurRadius: 20 + _angerLevel,
                            spreadRadius: _angerLevel * 0.2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.local_fire_department,
                            size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '꾹 눌러서 태워버리기 ${(_angerLevel).toInt()}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
