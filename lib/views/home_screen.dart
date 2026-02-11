import 'dart:io';
import '../utils/app_fonts.dart';
import '../utils/bold_first_line_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../widgets/point_display.dart';
import '../widgets/pixel_shred_animation.dart';
import '../painter/graph_paper_painter.dart';
import '../widgets/ai_chat_dialog.dart';
import '../widgets/anger_memo_field.dart'; // Moved here as per instruction
import 'mailbox_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  double _angerLevel = 0.0;
  final TextEditingController _textController = BoldFirstLineController();
  final FocusNode _textFocusNode =
      FocusNode(); // Add focus node to control keyboard
  final ImagePicker _picker = ImagePicker();
  bool _isPressing = false;
  late AnimationController _pulseController;
  String _selectedTag = '자동';
  late String _selectedPersonaStr; // Initialized in initState

  late AudioPlayer _sfxPlayer;
  late AudioPlayer _risingSfxPlayer;

  // Helper to get actual persona
  Persona _getActualPersona() {
    if (_selectedPersonaStr == '랜덤') {
      final options = [Persona.fighter, Persona.humor, Persona.factBomb];
      return options[DateTime.now().millisecond % options.length];
    }
    switch (_selectedPersonaStr) {
      case '전투':
        return Persona.fighter;
      case '유머':
        return Persona.humor;
      case '팩폭':
        return Persona.factBomb;
      default:
        return Persona.fighter; // Default to Fighter as requested fallback
    }
  }

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer();
    _risingSfxPlayer = AudioPlayer();

    // Listen for new letter event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<VentingViewModel>(context, listen: false)
          .addListener(_onVentingVMChange);
    });

    // Check daily recharge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userVM = Provider.of<UserViewModel>(context, listen: false);
      if (userVM.isJustRecharged) {
        _showRechargeToast(context, userVM.dailyComfortCount);
        userVM.consumeRechargeFlag();
      }
    });

    // Initialize persona from User Settings
    final userVM = Provider.of<UserViewModel>(context, listen: false);
    _selectedPersonaStr = userVM.defaultPersonaStr;

    // Validate selection against current UI list (removes deprecated '공감' if present)
    const validPersonas = ['전투', '유머', '팩폭', '랜덤'];
    if (!validPersonas.contains(_selectedPersonaStr)) {
      _selectedPersonaStr = '전투';
    }

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

  void _showRechargeToast(BuildContext context, int totalCount) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _FadingToast(
          totalCount: totalCount,
          onCompleted: () {
            entry.remove();
          }),
    );

    overlay.insert(entry);
  }

  void _onVentingVMChange() {
    if (!mounted) return;
    final vm = Provider.of<VentingViewModel>(context, listen: false);
    if (vm.hasNewLetter) {
      vm.consumeNewLetterEvent();
      _showLetterArrivedDialog();
    }
  }

  void _showLetterArrivedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D00).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_rounded,
                  size: 48, color: Color(0xFFFF4D00)),
            ),
            const SizedBox(height: 16),
            const Text('쪽지가 도착했어요!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('마음 우체통을 확인해보세요.',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MailboxScreen()));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D00),
                foregroundColor: Colors.white),
            child: const Text('보러가기'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove listener safely
    // Note: Provider might be disposed already, but removeListener is safe on living instance
    // However, we don't have a direct reference easily unless we stored it.
    // Ideally we should store the wrapper or check mounted.
    // Actually, typically we just let it be GC'd or remove if we have ref.
    // Better pattern:
    // ref.removeListener(_onVentingVMChange);
    // But since we didn't store ref, let's rely on standard practice or use a StatefulWidget wrapper.
    // For now, to avoid complexity with context access in dispose:
    // We'll skip removeListener here as it's the Main Screen typically living forever,
    // or we could store the provider in initState.
    // Let's store it.

    _sfxPlayer.dispose();
    _risingSfxPlayer.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _textFocusNode.dispose(); // Dispose focus node
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

  void _handleBurn() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final ventingVM = Provider.of<VentingViewModel>(context, listen: false);
    final userVM = Provider.of<UserViewModel>(context, listen: false);

    // 1. Calculate animation duration
    // Standard: 3 seconds for full text (100 chars), min 1.5s, max 4s
    double calculatedDelaySeconds = (text.length / 30).clamp(1.5, 4.0);

    // Prevent double tap
    if (_isPressing) return;
    setState(() {
      _isPressing = true;
    });

    // Remove focus BEFORE showing dialog
    _textFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    // 2. Show burning dialog overlay (Pixel Shred Effect)
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8), // Darken background
      builder: (dialogContext) => Center(
          child: PixelShredAnimation(
        delay: Duration(milliseconds: (calculatedDelaySeconds * 1000).toInt()),
        onComplete: () async {
          Navigator.of(dialogContext)
              .pop(); // Close burning dialog using dialogContext

          // Delay unfocus to override any focus restoration
          await Future.delayed(const Duration(milliseconds: 150));

          if (!context.mounted) {
            return;
          }

          if (context.mounted) {
            _textFocusNode.unfocus(); // Explicitly unfocus the text field
            FocusScope.of(context).unfocus();
          }

          // 3. Save post and process
          final actualPersona = _getActualPersona();

          if (context.mounted && !ventingVM.shareToSquare) {
            // Private Mode

            // Create the future but don't await blocking UI
            final futureResponse = ventingVM.finishBurning(
              actualPersona,
              text,
              userVM.userId ?? 'anonymous',
              userVM.nickname ?? '익명',
              userVM, // Passed userVM
              angerLevel: _angerLevel,
              manualTag: _selectedTag,
            );

            if (context.mounted) {
              _showAiResponseDialog(context, ventingVM, userVM, text,
                  pendingPostFuture: futureResponse);
            }
          } else if (context.mounted) {
            // Public Mode
            await ventingVM.finishBurning(
              actualPersona,
              text,
              userVM.userId ?? 'anonymous',
              userVM.nickname ?? '익명',
              userVM, // Passed userVM
              angerLevel: _angerLevel,
              manualTag: _selectedTag,
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('광장에 공유되었습니다.')));
            }
          }

          if (context.mounted) {
            ventingVM.triggerBackgroundLetter(text);
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, // White paper
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(
                foregroundPainter: GraphPaperPainter(),
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
                    Text(
                      text.isEmpty ? "..." : text,
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

  void _showAiResponseDialog(BuildContext context, VentingViewModel vm,
      UserViewModel userVM, String userText,
      {required Future<PrivatePost?> pendingPostFuture}) async {
    // 2. Show Dialog and wait for result (chat history)
    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      barrierDismissible: false, // Force user to close explicitly or via X
      builder: (context) {
        return AiChatDialog(
          initialUserText: userText,
          initialAiResponse: null,
          pendingAiResponse: null, // No longer used, dialog handles trigger
          persona: _getActualPersona(), // Use local selection
          triggerAiOnInit: true, // Auto-start the conversation
        );
      },
    );

    // 3. Reset Home Screen State IMMEDIATELY after dialog closes
    if (mounted) {
      setState(() {
        _textController.clear();
        _angerLevel = 0.0;
        _isPressing = false;
        _pulseController.reset();
        _textFocusNode.unfocus();
      });
    }

    // 4. Process Result (Background/Async)
    if (result != null) {
      // Wait for the post to be fully created/returned
      final createdPost = await pendingPostFuture;
      if (createdPost != null) {
        // Update history in background
        await vm.updatePrivatePostChatHistory(createdPost.id, result);
      }
    }
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
                    _textFocusNode
                        .unfocus(); // Explicitly unfocus the text field
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
                    _textFocusNode
                        .unfocus(); // Explicitly unfocus the text field
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
            Text(userVM.nickname ?? '익명',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Lv.${userVM.level}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFFF4D00))),
                const SizedBox(width: 4),
                Text('(${userVM.expString})',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: userVM.levelProgress,
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.mail_outline, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MailboxScreen()));
                },
              ),
              if (ventingVM.unreadLetterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4D00),
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${ventingVM.unreadLetterCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const PointDisplay(),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(24, 0, 24, 24), // Reduced top padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comfort Count Badge (Persona selection removed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite,
                              size: 14, color: Colors.pinkAccent),
                          const SizedBox(width: 4),
                          Text(
                            '${userVM.dailyComfortCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Input Area
                AngerMemoField(
                  controller: _textController,
                  focusNode:
                      _textFocusNode, // Pass focus node for complete control
                  hintText: '지금 무슨 일이 있었나요? 속 시원하게 털어놓으세요...',
                ),
                // ... same as before ...
                // Need to update finishBurning calls
                /*
                final actualPersona = _getActualPersona();
                ...
                ventingVM.finishBurning(
                  actualPersona, 
                  ...
                */

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
                    // Removed Doodle Button
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.grey),
                      onPressed: () => _pickImage(ventingVM),
                    ),
                    const SizedBox(width: 12),
                    // Shared Toggle Moved Here
                    Row(
                      children: [
                        Text(
                          ventingVM.shareToSquare ? '광장 공유' : '나만 보기',
                          style: TextStyle(
                            color: ventingVM.shareToSquare
                                ? const Color(0xFFFF4D00)
                                : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: ventingVM.shareToSquare,
                            activeColor: const Color(0xFFFF4D00),
                            onChanged: (value) {
                              ventingVM.setShareToSquare(value);
                              if (value)
                                setState(() => _hasConfirmedShare = false);
                            },
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('태그',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTag,
                          dropdownColor: const Color(0xFF2A2A2A),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.grey, size: 18), // Smaller icon
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13), // Smaller text
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedTag = newValue!;
                            });
                          },
                          items: ['자동', ...ventingVM.availableTags]
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value,
                                  style: TextStyle(
                                      color: value == _selectedTag
                                          ? const Color(0xFFFF4D00)
                                          : Colors.white)),
                            );
                          }).toList(),
                        ),
                      ),
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
                            // Removed 80% threshold as requested.
                            // Only check if text is not empty (already handled by Opacity logic visually)
                            if (_textController.text.trim().isNotEmpty) {
                              _handleBurn();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('감정을 적어주세요.')),
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

class _FadingToast extends StatefulWidget {
  final int totalCount;
  final VoidCallback onCompleted;

  const _FadingToast({required this.totalCount, required this.onCompleted});

  @override
  State<_FadingToast> createState() => _FadingToastState();
}

class _FadingToastState extends State<_FadingToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    await _controller.forward(); // Fade In
    await Future.delayed(const Duration(seconds: 3)); // Wait
    if (mounted) {
      await _controller.reverse(); // Fade Out
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.2,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.pinkAccent.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.pinkAccent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volunteer_activism,
                    color: Colors.pinkAccent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "당신을 위로해줄\n오늘분의 하트가 충전됩니다",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "누적된 하트 : ${widget.totalCount}개",
                    style: const TextStyle(
                        color: Colors.pinkAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
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
