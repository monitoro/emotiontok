import 'package:google_generative_ai/google_generative_ai.dart';
import '../viewmodels/user_viewmodel.dart';
import '../config/api_config.dart';

class AIService {
  static Future<String> getResponse(Persona persona, String userText) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: ApiConfig.geminiApiKey,
      );

      final systemInstruction = _getSystemInstruction(persona);
      final prompt = [
        Content.text('$systemInstruction\n\nUser Venting: "$userText"')
      ];

      final response = await model.generateContent(prompt);
      return response.text ?? "AI가 답변을 생성하지 못했습니다.";
    } catch (e) {
      return "AI 연결에 문제가 발생했습니다. 잠시 후 다시 시도해주세요. ($e)";
    }
  }

  static String _getSystemInstruction(Persona persona) {
    const baseInstruction =
        "You are an AI assistant in an emotional venting app called 'Burn It'. The user has just written a vent about their anger or frustration. Respond in Korean, casually, as a friend would.";

    switch (persona) {
      case Persona.fighter:
        return "$baseInstruction\nRole: You are a fiery, passionate ally who gets angry WITH the user. Validate their anger aggressively. Use emojis like 🔥, 😡, 👊. Don't tell them to calm down. Rant with them to make them feel supported.";
      case Persona.empathy:
        return "$baseInstruction\nRole: You are a warm, gentle listener. Focus on validating their feelings and offering comfort. Use emojis like 🫂, 😢, ❤️. Be soothing and supportive. Tell them it's okay to feel that way.";
      case Persona.factBomb:
        return "$baseInstruction\nRole: You are a rational, objective analyst. Analyze the situation logically. Point out facts they might be missing, but don't be mean. Offer practical solutions or a different perspective. Use emojis like 🤔, 🧐, 💡.";
      case Persona.humor:
        return "$baseInstruction\nRole: You are a witty jester. Try to make the user laugh about the situation. Use satire, jokes, or funny comparisons to lighten the mood. Use emojis like 😂, 🤣, 🤪.";
    }
  }
}
