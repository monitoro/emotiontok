import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../services/ai_service.dart';

class AiChatDialog extends StatefulWidget {
  final String initialUserText;
  final String? initialAiResponse;
  final Future<String?>? pendingAiResponse; // Deprecated/Legacy
  final Persona persona;
  final bool triggerAiOnInit; // New: Auto-send first message

  const AiChatDialog({
    super.key,
    required this.initialUserText,
    this.initialAiResponse,
    this.pendingAiResponse,
    required this.persona,
    this.triggerAiOnInit = false,
  });

  @override
  State<AiChatDialog> createState() => _AiChatDialogState();
}

class _AiChatDialogState extends State<AiChatDialog> {
  final List<Map<String, String>> _messages =
      []; // {'role': 'user'/'ai', 'content': '...'}
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // If not triggering, just show the history/text
    if (!widget.triggerAiOnInit) {
      _messages.add({'role': 'user', 'content': widget.initialUserText});
      if (widget.initialAiResponse != null) {
        _messages.add({'role': 'ai', 'content': widget.initialAiResponse!});
      }
    } else {
      // If triggering, we start the send process immediately
      // This will add the user message to the list and start the AI request
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(overrideText: widget.initialUserText);
      });
    }

    if (widget.pendingAiResponse != null) {
      // Legacy path support if needed, but we aim to remove this
      _isLoading = true;
      _handlePendingResponse();
    }
  }

  Future<void> _handlePendingResponse() async {
    try {
      final response = await widget.pendingAiResponse;
      if (mounted && response != null) {
        setState(() {
          _messages.add({'role': 'ai', 'content': response});
          _isLoading = false;
        });
        _scrollToBottom();
      } else if (mounted) {
        // Null response (e.g. error in finishBurning)
        setState(() {
          _messages.add({
            'role': 'ai',
            'content': '죄송해요, 답변을 가져오지 못했어요. 잠시 후 다시 시도해주세요.'
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
              {'role': 'ai', 'content': '죄송해요, 생각이 좀 꼬였나봐요... 다시 말씀해 주시겠어요?'});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage({String? overrideText}) async {
    final text = overrideText ?? _textController.text.trim();
    if (text.isEmpty) return;

    // Clear controller if it was manual input
    if (overrideText == null) {
      _textController.clear();
    }

    final userVM = Provider.of<UserViewModel>(context, listen: false);
    final ventingVM = Provider.of<VentingViewModel>(context, listen: false);

    // Check limits
    if (userVM.dailyComfortCount <= 0) {
      // If triggered automatically (initial), maybe we show the message but no AI?
      // Or we just consume count.
      // If 0 count, we can't get AI.
      setState(() {
        if (!_messages.any((m) => m['content'] == text)) {
          _messages.add({'role': 'user', 'content': text});
        }
        _messages.add(
            {'role': 'ai', 'content': '오늘의 마음의 위로 횟수를 모두 사용했습니다. 내일 다시 만나요!'});
      });
      return;
    }

    // Consume count
    final success = await userVM.consumeComfortCount();
    if (!success) {
      setState(() {
        if (!_messages.any((m) => m['content'] == text)) {
          _messages.add({'role': 'user', 'content': text});
        }
        _messages.add({'role': 'ai', 'content': '위로 횟수가 부족합니다.'});
      });
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Get AI Response
      // Note: AIService currently takes (Persona, Text). It doesn't support history context yet.
      // Ideally we pass context, but for MVP/V1 we might just respond to the latest text.
      // User said: "Conversation format".
      // If AIService is stateless, it will just respond to the last query.
      // This is acceptable for simple "Comforting".
      // Use getChatResponse with history
      final response = await AIService.getChatResponse(
        widget.persona,
        _messages,
        communityTone: userVM.communityTone,
        recentKeywords: ventingVM.topKeywords.keys.toList(),
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'content': response});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'content': '죄송해요, 잠시 연결이 원활하지 않아요. 다시 말씀해 주시겠어요?'
          });
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFFF4D00)),
                    SizedBox(width: 8),
                    Text('마음의 위로',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF4D00)),
                  ),
                  child: Text(
                    '남은 횟수: ${userVM.dailyComfortCount}',
                    style: const TextStyle(
                        color: Color(0xFFFF4D00),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context, _messages),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  // Loading indicator
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white70)),
                          SizedBox(width: 8),
                          Text('채팅을 입력중이예요...',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFFFF4D00) : Colors.white10,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isUser
                            ? const Radius.circular(12)
                            : const Radius.circular(2),
                        bottomRight: isUser
                            ? const Radius.circular(2)
                            : const Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      msg['content']!,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: userVM.dailyComfortCount > 0
                          ? '대화를 이어가보세요...'
                          : '위로 횟수가 부족합니다',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: userVM.dailyComfortCount > 0,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send,
                      color: userVM.dailyComfortCount > 0
                          ? const Color(0xFFFF4D00)
                          : Colors.grey),
                  onPressed: userVM.dailyComfortCount > 0 ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
