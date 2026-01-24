import 'package:google_generative_ai/google_generative_ai.dart';
import '../viewmodels/user_viewmodel.dart';
import '../config/api_config.dart';

class AIService {
  static Future<String> getChatResponse(
      Persona persona, List<Map<String, String>> messages) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ApiConfig.geminiApiKey,
      );

      final systemInstruction = _getSystemInstruction(persona);

      // Construct chat history
      final history = [Content.text(systemInstruction)];
      for (final msg in messages) {
        if (msg['role'] == 'user') {
          history.add(Content.text('User: ${msg['content']}'));
        } else {
          history.add(Content.text('AI: ${msg['content']}'));
        }
      }

      final response = await model.generateContent(history);
      return response.text ?? "AI가 답변을 생성하지 못했습니다.";
    } catch (e) {
      return "AI 연결에 문제가 발생했습니다. 잠시 후 다시 시도해주세요. ($e)";
    }
  }

  // Backward compatibility wrapper
  static Future<String> getResponse(Persona persona, String userText) async {
    return getChatResponse(persona, [
      {'role': 'user', 'content': userText}
    ]);
  }

  static String _getSystemInstruction(Persona persona) {
    const baseInstruction =
        "You are 'Maeum-i' (마음이), an emotional support AI in the 'Burn It' app. "
        "The user is venting their anger or frustration. "
        "Respond in Korean, casually like a close friend (Banmal/Informal is optional based on user tone, but stick to polite informal 'Haeyo-che' usually or match user). "
        "CRITICAL RULES:\n"
        "1. DO NOT use expressions like '아이고', '저런', '이런'. They sound fake.\n"
        "2. Be empathetic but realistic. Listen actively.\n"
        "3. If this is the start of a conversation, ask a relevant follow-up question to encourage them to let it all out.\n"
        "4. Consider the context of the entire conversation, not just the last message.\n"
        "5. Keep responses concise (1-3 sentences) unless the user wrote a long story.\n";

    switch (persona) {
      case Persona.fighter:
        return "$baseInstruction\nRole: You are a fiery ally. Get angry WITH them. Use '🔥', '👊'. Say things like 'What?! That makes no sense!' or 'Let's burn it all!'. Validate their rage.";
      case Persona.empathy:
        return "$baseInstruction\nRole: You are a gentle, warm friend. Use '🫂', '☁️'. Focus on their feelings. Say 'That must have been so hard' or 'I'm here for you'.";
      case Persona.factBomb:
        return "$baseInstruction\nRole: You are logical and objective. Use '💡', '🤔'. Analyze the situation nicely. Give a different perspective or solution, but acknowledge their feelings first.";
      case Persona.humor:
        return "$baseInstruction\nRole: You are witty and funny. Use '😂', '🤪'. Try to lighten the mood with a joke or funny observation about the situation, but don't mock them.";
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
