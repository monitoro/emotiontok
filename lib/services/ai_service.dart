import '../viewmodels/user_viewmodel.dart';
import 'dart:math';

class AIService {
  // Simple local mock for AI responses based on persona
  static Future<String> getResponse(Persona persona, String userText) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    final Map<Persona, List<String>> responses = {
      Persona.fighter: [
        "정말 어처구니없네요! 제가 대신 화내드릴게요. 🔥",
        "그런 인간은 그냥 무시가 답이에요. 여기서 다 태워버려요!",
        "완전 공감합니다! 세상에 그런 무례한 사람이 있다니요.",
      ],
      Persona.empathy: [
        "오늘 정말 힘드셨겠어요. 마음이 많이 아프시죠? 🫂",
        "괜찮아요, 여기서 다 털어내세요. 제가 당신 편이에요.",
        "많이 속상하셨을 것 같아요. 충분히 화낼 만한 상황입니다.",
      ],
      Persona.factBomb: [
        "감정 소모보다는 상황 해결에 집중해볼까요? 🧐",
        "사실 그건 본인의 잘못이 아닙니다. 객관적으로 보세요.",
        "이미 지난 일입니다. 에너지를 낭비하지 마세요.",
      ],
      Persona.humor: [
        "하하, 그 사람 혹시 개그맨인가요? 아니면 그냥 바보? 😂",
        "이 상황을 만화로 그리면 정말 웃기겠는데요?",
        "웃음으로 승화시켜 봅시다. 제가 웃긴 이야기 하나 해드릴까요?",
      ],
    };

    final random = Random();
    final list = responses[persona] ?? responses[Persona.empathy]!;
    return list[random.nextInt(list.length)];
  }
}
