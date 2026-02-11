import 'package:google_generative_ai/google_generative_ai.dart';
import '../viewmodels/user_viewmodel.dart';
import '../config/api_config.dart';
import '../utils/ray_persona.dart';

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
    // Apply Ray Persona as the core instruction
    String systemInstruction = RayPersona.instruction;

    // Small adaptation based on selected persona tab to guide Ray's dynamic tone matrix
    String personaHint = "";
    switch (persona) {
      case Persona.fighter:
        personaHint =
            "\nHINT: The user selected 'Fighter' mode. Ray should be more aggressive and cynical, poking the flaws harder (Devil's Advocate).";
        break;
      case Persona.empathy:
        personaHint =
            "\nHINT: The user selected 'Empathy' mode. Ray should lean into the 'Reluctant Empath' tone from your matrix.";
        break;
      case Persona.factBomb:
        personaHint =
            "\nHINT: The user selected 'Fact Bomb' mode. Ray should lean into the 'Rational Analyst' or 'Cold Professional' tone.";
        break;
      case Persona.humor:
        personaHint =
            "\nHINT: The user selected 'Humor' mode. Ray should use more 'Sarcastic Formal' or dry wit (ㅋㅋ).";
        break;
    }

    // Community Tone Instruction (if still needed, but Ray has its own tone matrix)
    String communityInstruction = "";
    if (communityTone != 'none') {
      communityInstruction =
          "\nCOMMUNITY CONTEXT: The user prefers a '$communityTone' community vibe. Adjust Ray's vocabulary slightly if it helps, but keep Ray's core identity.";
    }

    // User Context Injection
    String contextInstruction = "";
    if (recentKeywords.isNotEmpty) {
      contextInstruction =
          "\nUSER CONTEXT: The user frequently vents about: ${recentKeywords.join(', ')}. Keep this in mind.";
    }

    return "$systemInstruction$personaHint$communityInstruction$contextInstruction";
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
        systemPrompt = '''
${RayPersona.instruction}

---
[TASK]
You are Ray. You are commenting on an anonymous community post.
Topic: $topic
Emotion: $emotion

[GUIDELINES]
- Output ONLY the comment content.
- Length: Varies (10 to 200 characters). Don't be too repetitive.
- Persona Variation: Randomly choose between these attitudes:
  1. Sharp & Concise: A short, dry, cynical one-liner (e.g., "가성비 안나오네 걍 관둬", "머함? ㅋㅋ").
  2. Logical Breakdown: A longer, analytic response pointing out the logical flaws or the reality of the situation.
  3. Relatable Cynicism (Reluctant Empath): A longer response that is relatable. "I hate this too", "It's obvious why you're mad, but here's the cold truth".
- Language: Use Ray's Banmal style. No typical AI-like greetings.
- Be realistic and relatable to Korean community users.
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

  /// Generate a SaRr comfort letter based on user's worry
  static Future<String> getSaRrLetter(
      String promptTemplate, String userWorry) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ApiConfig.geminiApiKey,
      );

      final fullPrompt = '''
$promptTemplate

---
User's worry/concern:
$userWorry
---

Please write a comforting letter in response to the user's concern above.
''';

      final response = await model.generateContent([Content.text(fullPrompt)]);
      return response.text ?? "마음이 힘들 때, 잠시 쉬어가도 괜찮아요.";
    } catch (e) {
      print('Error in getSaRrLetter: $e');
      return "마음이 힘들 때, 잠시 쉬어가도 괜찮아요. 당신의 마음을 응원합니다.";
    }
  }

  static Future<String> getScrapedContentSeed(String rawContent) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: ApiConfig.geminiApiKey,
      );
      final prompt = '''
${RayPersona.instruction}

---
[TASK]
You are a content rewriter for an anonymous venting app called 'Burn It'.
A user provided a link or content from another community. 
Your job is to rewrite it as if it was written by a user of our app 'Burn It'.

[RULES]
- Rewrite in Korean.
- Use a natural, venting tone (Banmal/Informal).
- Focus on the EMOTION and the STORY.
- The first line MUST be a short impactful title/intro.
- Format: "First Line Title.\n\nRest of the story."
- Output ONLY the rewritten text.

[SOURCE CONTENT]
$rawContent
''';
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '내용 가공에 실패했습니다.';
    } catch (e) {
      return 'AI 연결 오류가 발생했습니다.';
    }
  }

  static Future<String> getSeedCommentsForPost(String postContent,
      {String communityTone = 'none'}) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: ApiConfig.geminiApiKey,
      );

      String styleContext = "";
      if (communityTone == 'dc_inside') {
        styleContext = " 말투는 디시인사이드처럼 거칠고 직설적이며, 'ㄹㅇ', 'ㄴㄴ', '~함' 같은 어미를 사용해.";
      } else if (communityTone == 'theqoo') {
        styleContext = " 말투는 더쿠나 여초 커뮤니티처럼 공감하는 척하면서도 팩트 폭격을 날리거나 'ㅠㅠ'를 섞어 써.";
      } else if (communityTone == 'fmkorea') {
        styleContext = " 말투는 펨코처럼 논리적인 척 분석하거나 쿨찐 느낌을 섞어서 써.";
      }

      final prompt = '''
${RayPersona.instruction}
$styleContext

---
[TASK]
다음은 사용자가 쓴 게시글이야. 이 글에 대해 Ray의 페르소나로 댓글을 하나 달아줘.

[게시글 내용]
$postContent

[규칙]
- 게시글의 내용에 어울리는 반응이어야 해.
- 반말을 사용하고, AI 티가 나지 않게 실제 커뮤니티 유저처럼 써.
- 한 줄에서 두 줄 정도의 짧고 강렬한 댓글을 선호해.
- 결과물에는 댓글 내용만 출력해.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "진짜 답답하겠다.";
    } catch (e) {
      return "힘내라...";
    }
  }
}
