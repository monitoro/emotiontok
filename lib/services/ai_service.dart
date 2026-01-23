import 'package:google_generative_ai/google_generative_ai.dart';
import '../viewmodels/user_viewmodel.dart';
import '../config/api_config.dart';

class AIService {
  static Future<String> getResponse(Persona persona, String userText) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
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

  static Future<String> getSeedContent(String topic, String emotion) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ApiConfig.geminiApiKey,
      );

      final prompt = [
        Content.text('''
You are a creative writer generating fake user posts for an anonymous emotional venting app called 'Burn It'.
Generate a short, realistic, and emotional post in Korean.
Topic: $topic
Emotion: $emotion
Length: 30-80 characters.
Style: Casual, internet slang allowed but not excessive, authentic, anonymous venting.
Output only the post content, no quotes or extra text.
''')
      ];

      final response = await model.generateContent(prompt);
      return response.text?.trim() ?? "오늘 하루도 정말 쉽지 않네...";
    } catch (e, stackTrace) {
      print('Error in getSeedContent: $e');
      print(stackTrace);
      return "그냥 아무 생각 없이 멍때리고 싶다.";
    }
  }
}
