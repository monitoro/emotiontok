import 'dart:io';
import '../utils/app_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:audioplayers/audioplayers.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../widgets/doodle_view.dart';
import '../widgets/point_display.dart';
import '../widgets/pixel_shred_animation.dart';
import '../painter/graph_paper_painter.dart';
import '../widgets/anger_memo_field.dart';

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

  late AudioPlayer _sfxPlayer;
  late AudioPlayer _risingSfxPlayer;

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    _risingSfxPlayer = AudioPlayer();

    _risingSfxPlayer.setReleaseMode(ReleaseMode.loop); // Loop for rising effect

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        if (_isPressing) {
          setState(() {
            _angerLevel = _pulseController.value * 100;
          });

          // Adjust volume based on anger level
          if (_pulseController.value > 0) {
            _risingSfxPlayer.setVolume(_pulseController.value.clamp(0.1, 1.0));
          }
        }
      });
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    _risingSfxPlayer.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  bool _hasConfirmedShare = false;

  void _startPressing() async {
    // If sharing is enabled and not yet confirmed, do not start pressing.
    // This logic is now handled in onLongPressStart before calling this,
    // but we keep a check here just in case.
    setState(() => _isPressing = true);
    _pulseController.forward();

    final userVM = Provider.of<UserViewModel>(context, listen: false);
    if (userVM.isSfxOn) {
      try {
        await _risingSfxPlayer.setVolume(0.1); // Start low
        await _risingSfxPlayer.play(AssetSource('sounds/burn_charge.mp3'));
      } catch (e) {
        // debugPrint('Rising SFX failed: $e');
      }
    }
  }

  void _stopPressing() {
    setState(() => _isPressing = false);
    _pulseController.reset();
    _risingSfxPlayer.stop();
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
    ventingVM.startBurning();

    // Play burning SFX if enabled
    if (userVM.isSfxOn) {
      try {
        _sfxPlayer.play(AssetSource('sounds/explosion.mp3'));
      } catch (e) {
        debugPrint('SFX play failed: $e');
      }
    }

    // Calculate delay based on text length (2s ~ 4s)
    final double calculatedDelaySeconds =
        (2.0 + (text.length / 50.0)).clamp(2.0, 4.0);

    // Remove focus BEFORE showing dialog to prevent auto-restoration
    FocusScope.of(context).unfocus();

    // 2. Show burning dialog overlay (Pixel Shred Effect)
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8), // Darken background
      builder: (context) => Center(
          child: PixelShredAnimation(
        delay: Duration(milliseconds: (calculatedDelaySeconds * 1000).toInt()),
        onComplete: () async {
          Navigator.of(context).pop(); // Close burning dialog
          // Delay unfocus to override any focus restoration
          await Future.delayed(const Duration(milliseconds: 150));
          if (context.mounted) {
            FocusScope.of(context).unfocus();
          }

          // 3. Save post and process
          ventingVM.finishBurning(
            userVM.selectedPersona,
            text,
            userVM,
            angerLevel: _angerLevel,
          );

          _textController.clear();
          _signatureController.clear();
          setState(() {
            _angerLevel = 0;
            _hasConfirmedShare = false; // Reset confirmation
          });

          // Show AI response dialog
          if (context.mounted) {
            _showAiResponseDialog(context, ventingVM);
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, // White paper
              borderRadius:
                  BorderRadius.circular(4), // Sharp corners like paper
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(
                foregroundPainter: GraphPaperPainter(), // Draw grid on top
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ventingVM.pickedImagePath != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(ventingVM.pickedImagePath!,
                                  height: 150)
                              : Image.file(File(ventingVM.pickedImagePath!),
                                  height: 150),
                        ),
                      ),
                    if (ventingVM.currentMode == VentingMode.doodle &&
                        ventingVM.doodleData != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Image.memory(ventingVM.doodleData!),
                      ),
                    Text(
                      text.isEmpty
                          ? (ventingVM.currentMode == VentingMode.doodle
                              ? "(그림으로 표현된 마음)"
                              : "...")
                          : text,
                      style: AppFonts.getFont(
                        userVM.selectedFont,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )),
          ),
        ),
      )),
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
              Text('마음이의 위로', style: TextStyle(color: Colors.white)),
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
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
              child: const Text('닫기', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showSafetyDialog(BuildContext context, VentingViewModel ventingVM) {
    // Remove focus BEFORE showing dialog to prevent auto-restoration
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('잠깐만요!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          '모두가 보는 공간에 마음이 표현됩니다.\n개인이 특정되는 정보의 노출 위험이 없는지 다시 한번 확인해 주세요.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Close dialog first
                  // Delay unfocus to override any focus restoration (150ms is enough)
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    FocusScope.of(context).unfocus();
                  }

                  ventingVM.setShareToSquare(true);
                  setState(() => _hasConfirmedShare = true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('확인되었습니다. 버튼을 꾹 눌러 태워주세요!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D00),
                  foregroundColor: Colors.white,
                ),
                child: const Text('네, 이해했습니다'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context); // Close dialog
                  // Delay unfocus to override any focus restoration
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (context.mounted) {
                    FocusScope.of(context).unfocus();
                  }

                  ventingVM.setShareToSquare(false);
                  setState(() => _hasConfirmedShare = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('나만 보는 공간에 남깁니다.')),
                    );
                  }
                },
                child: const Text(
                  '아니요. 나만의 마음으로 남길래요.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ventingVM = Provider.of<VentingViewModel>(context);
    final userVM = Provider.of<UserViewModel>(context);

    // ... (rest of the build method up to the button loop) ...
    // Note: I cannot see the FULL file to replace selectively in the middle easily without context matching.
    // I will replace the Button area in the next step or try to match a larger block.
    // Actually, I can match the GestureDetector part easily.

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
                  // If turning ON, reset confirmation so they see the dialog again next time
                  if (value) setState(() => _hasConfirmedShare = false);

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
                ventingVM.currentMode == VentingMode.text
                    ? AngerMemoField(
                        controller: _textController,
                        hintText: '지금 무슨 일이 있었나요? 속 시원하게 털어놓으세요...',
                      )
                    : Container(
                        height: 300,
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
                        child: DoodleView(controller: _signatureController),
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
                  child: Column(
                    children: [
                      Text(
                        '꾹 눌러서 태워버리기 ${(_angerLevel).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onLongPressStart: (_) {
                          if (ventingVM.shareToSquare && !_hasConfirmedShare) {
                            // Intercept: Show safety dialog immediately
                            _showSafetyDialog(context, ventingVM);
                          } else {
                            // Proceed as normal
                            _startPressing();
                          }
                        },
                        onLongPressEnd: (_) {
                          // If we never started pressing (because of dialog), this shouldn't matter much
                          // but we should ensure we stop cleanly.
                          if (_isPressing) {
                            _stopPressing();
                            if (_angerLevel >= 80) {
                              // Just burn, no more dialogs here since we handled safety check at start
                              _burnEmotions(_textController.text);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('감정을 더 모아서 꾹 눌러주세요! (80% 이상)')),
                              );
                            }
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
                    ],
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
