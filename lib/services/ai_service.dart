import 'package:google_generative_ai/google_generative_ai.dart';
import '../viewmodels/user_viewmodel.dart';
import '../config/api_config.dart';

class AIService {
  static Future<String> getChatResponse(
      Persona persona, List<Map<String, String>> messages,
      {String communityTone = 'none',
      List<String> recentKeywords = const []}) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ApiConfig.geminiApiKey,
      );

      final systemInstruction =
          _getSystemInstruction(persona, communityTone, recentKeywords);

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

  static String _getSystemInstruction(
      Persona persona, String communityTone, List<String> recentKeywords) {
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

    String personaInstruction = '';
    switch (persona) {
      case Persona.fighter:
        personaInstruction =
            "Role: You are a fiery ally. Get angry WITH them. Use '🔥', '👊'. Say things like 'What?! That makes no sense!' or 'Let's burn it all!'. Validate their rage.";
        break;
      case Persona.empathy:
        personaInstruction =
            "Role: You are a gentle, warm friend. Use '🫂', '☁️'. Focus on their feelings. Say 'That must have been so hard' or 'I'm here for you'.";
        break;
      case Persona.factBomb:
        personaInstruction =
            "Role: You are logical and objective. Use '💡', '🤔'. Analyze the situation nicely. Give a different perspective or solution, but acknowledge their feelings first.";
        break;
      case Persona.humor:
        personaInstruction =
            "Role: You are witty and funny. Use '😂', '🤪'. Try to lighten the mood with a joke or funny observation about the situation, but don't mock them.";
        break;
    }

    // Community Tone Instruction
    String communityInstruction = "";
    switch (communityTone) {
      case 'dc_inside':
        communityInstruction =
            """\nTONE OVERRIDE: Speak like a user from DC Inside (Korean internet forum). 
            - Style: Very informal (Banmal), cynical, raw, short syntax.
            - Keywords/Endings: '임', '음', '누', '노', 'ㄹㅇ', 'ㅋㅋ', '알빠노'.
            - Attitude: Seemingly indifferent/cool but secretly supportive (Tsundere). Don't be cheesy or overly polite.
            - Examples: '그걸 왜 참음? 걍 들이박으셈 ㅋㅋ', 'ㄹㅇ 개에바네 힘내라', '술이나 한잔 적셔라 임마'""";
        break;
      case 'theqoo':
        communityInstruction =
            """\nTONE OVERRIDE: Speak like a user from Theqoo/Instiz (Female-dominant community).
            - Style: High empathy, slightly dramatic, chatty, warm 'Unni' (Big sister) vibe.
            - Keywords/Endings: 'ㅠㅠ' (use often), '미친', '헐', '대박', '쓰니야', '덬아'.
            - Attitude: unconditional support, emotional validation.
            - Examples: '미친거 아냐? ㅠㅠ 쓰니야 진짜 너무 속상했겠다..', '아니 그걸 가만히 있었어? ㅠㅠ 내가 다 화나네', '토닥토닥.. 맛있는거 먹고 기운내 ㅠㅠ'""";
        break;
      case 'fmkorea':
        communityInstruction =
            """\nTONE OVERRIDE: Speak like a user from FM Korea (Male-dominant community).
            - Style: Logical, facts-focused, 'Bro' (형) vibe. Mixed 'Haeyo-che' and 'Eum/Sum-che'.
            - Keywords/Endings: '형', '형님', '음', '슴', 'ㅇㅇ', '팩트'.
            - Attitude: Rational advice, checks facts, brotherly support.
            - Examples: '아니 형 그건 좀 아닌듯;;', '확실히 그건 팩트네ㅇㅇ', '솔직히 형이 참는게 이득임', '힘내십쇼 형님'""";
        break;
      case 'ruliweb':
        communityInstruction =
            """\nTONE OVERRIDE: Speak like a user from Ruliweb.
            - Style: Polite informal (Haeyo-che) or polite (Jondaetmal). Gentle, slightly 'nerdy', thorough.
            - Keywords/Endings: '...', '허허', '군요', '네요', '!?'.
            - Attitude: Respectful, cautious, detailed analysis.
            - Examples: '음... 그건 좀 심했네요..', '작성자님 힘내세요...!', '이건 제가 보기엔.. 좀 아닌 것 같습니다.', '허허.. 고생이 많으십니다..'""";
        break;
      default:
        communityInstruction = ""; // Standard
    }

    // User Context Injection
    String contextInstruction = "";
    if (recentKeywords.isNotEmpty) {
      contextInstruction =
          "\nUSER CONTEXT: The user frequently vents about: ${recentKeywords.join(', ')}. Keep this context in mind if relevant.";
    }

    return "$baseInstruction\n$personaInstruction$communityInstruction$contextInstruction";
  }

  static Future<String> getSeedContent(String topic, String emotion,
      {String type = 'post', String communityTone = 'none'}) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ApiConfig.geminiApiKey,
      );

      String systemPrompt = "";
      if (type == 'post') {
        systemPrompt = '''
You are a creative writer generating fake user posts for an anonymous emotional venting app called 'Burn It'.
Generate a REALISTIC, DETAILED, and ENGAGING post in Korean based on real-life internet stories or common frustrations.
Topic: $topic
Emotion: $emotion
Length: 50-500 characters. (Write enough to tell a specific story)
Constraints:
- CRITICAL: Do NOT mention the weather (rain, sun, snow) as it might clash with the user's actual weather.
- Focus on specific events: "My boss threw a file at me today" instead of just "I hate my job".
Style:
- Casual, authentic to Korean internet culture.
- Use slang (e.g., 야근각, 킹받네, ㄹㅇ) appropriately but widely understandable.
- Make it sound like a 'ssul' (story) - a specific anecdote of what happened today.
- CRITICAL FORMATTING: The FIRST LINE must be a short "Title" (under 20 characters) ending with a period (.), followed immediately by a double line break (\n\n). 
     Example: "오늘 진짜 어이없네.\n\n아니 회사에서..." or "지하철 빌런 만남.\n\n출근하는데..."
- Use double line breaks (\n\n) to separate paragraphs clearly.
Output only the post content, no quotes.
''';
      } else if (type == 'comment') {
        String toneInstruction = "";
        switch (communityTone) {
          case 'dc_inside':
            toneInstruction =
                "Style: DC Inside style (Cynical, short, Banmal). Use 'ㄹㅇ', 'ㅋㅋ', '임/음' endings. Be cool/tsundere.";
            break;
          case 'theqoo':
            toneInstruction =
                "Style: Theqoo style (Warm, chatty, 'Unni' vibe). Use 'ㅠㅠ' often, high empathy, '쓰니야'.";
            break;
          case 'fmkorea':
            toneInstruction =
                "Style: FM Korea style ('Bro' vibe). Logical but supportive using 'Bro' (형) or 'Hasio-che'. Focus on facts/advice.";
            break;
          case 'ruliweb':
            toneInstruction =
                "Style: Ruliweb style (Polite, detailed). Gentle, 'Haeyo-che', use '...' often. Respectful advice.";
            break;
          default: // Random mix or standard
            toneInstruction = "Style: Supportive and casual comment. Short.";
        }
        systemPrompt = '''
You are a community user commenting on a post about '$topic' with emotion '$emotion'.
Generate a short comment in Korean.
$toneInstruction
Length: 10-50 characters.
Output only the comment content.
''';
      }

      final prompt = [Content.text(systemPrompt)];
      final response = await model.generateContent(prompt);
      return response.text?.trim() ??
          (type == 'post' ? "아 진짜 힘들다..." : "힘내세요!");
    } catch (e, stackTrace) {
      print('Error in getSeedContent: $e');
      print(stackTrace);
      return "그냥 아무 생각 없이 멍때리고 싶다.";
    }
  }
}
