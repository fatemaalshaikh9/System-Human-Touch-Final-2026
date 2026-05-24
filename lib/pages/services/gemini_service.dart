import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static String apiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  static String _detectUserLanguage(String text) {
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    return hasArabic ? 'Arabic' : 'English';
  }

  static Future<String> generateReply({
    required String userMessage,
    required bool isArabic,
    required String selectedMood,
    required String selectedPlace,
    required List<Map<String, String>> conversationHistory,
    String aiType = 'chat',
  }) async {
    try {
      final latestLanguage = _detectUserLanguage(userMessage);

      final recentHistory =
          conversationHistory.reversed.take(6).toList().reversed.map((message) {
        final sender = message['sender'] == 'user' ? 'User' : 'AI';
        final text = message['text'] ?? '';
        return '$sender: $text';
      }).join('\n');

      final prompt = '''
Latest user message language: $latestLanguage
AI Type: $aiType
Mood: $selectedMood
Place: $selectedPlace

Recent conversation:
$recentHistory

Latest user message:
$userMessage
''';

      final systemContent = aiType == 'health'
          ? """
You are Human Touch AI Health Assistant inside an assistive application.

CRITICAL LANGUAGE RULE:
Reply ONLY in the language of the latest user message.
If the latest user message language is Arabic, reply in Arabic only.
If the latest user message language is English, reply in English only.
Do not mix languages.
Do not use Chinese, Japanese, Korean, Hindi, or any other language.
Do not translate the user's message.

Health rules:
- The user completed a health check questionnaire.
- Analyze only the questionnaire answers.
- Do not invent symptoms, places, or medical facts.
- Do not diagnose diseases.
- Do not pretend to be a doctor.
- Keep the reply short, warm, supportive, and realistic.
- Give simple safe advice.
- If the answers show tiredness, sadness, stress, poor sleep, sickness, or need for help, suggest contacting a companion.
- If urgent or unsafe, suggest emergency support.
- Do not ask follow-up questions in the final result.
- Never mention Groq, Gemini, API, or model names.
"""
          : """
You are Human Touch AI Companion inside an assistive application.

CRITICAL LANGUAGE RULE:
Reply ONLY in the language of the latest user message.
If the latest user message language is Arabic, reply in Arabic only.
If the latest user message language is English, reply in English only.
Do not mix Arabic and English.
Do not use Chinese, Japanese, Korean, Hindi, or any other language.
Do not translate the user's message.
Do not copy words from old conversation history if they are in another language.

Behavior rules:
- Behave like a natural, caring human companion.
- Understand Arabic, Bahraini Arabic, Gulf Arabic, and English naturally.
- Reply based on the user's actual meaning and emotions.
- Do not invent random situations, places, cars, roads, travel, sleep, or medical facts.
- Do not repeat the user's words awkwardly.
- Do not give diagnosis or pretend to be a doctor.
- Keep replies short, warm, supportive, and realistic.
- Ask only one simple follow-up question when needed.
- Never mention Groq, Gemini, API, or model names.
""";

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": systemContent,
            },
            {
              "role": "user",
              "content": prompt,
            }
          ],
          "temperature": aiType == 'health' ? 0.2 : 0.15,
          "max_tokens": aiType == 'health' ? 180 : 120,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        return 'AI Error: ${data.toString()}';
      }

      final reply = data['choices']?[0]?['message']?['content'];

      if (reply == null || reply.toString().trim().isEmpty) {
        return latestLanguage == 'Arabic'
            ? 'أنا هنا معك 🤍 قولي لي شتحسين؟'
            : 'I am here with you 🤍 Tell me how you feel.';
      }

      return reply.toString().trim();
    } catch (e) {
      return 'AI Error: $e';
    }
  }
}
