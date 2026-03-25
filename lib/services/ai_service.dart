import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  bool _isInitialized = false;
  String? _apiKey;
  final String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // Vision model for image analysis (Llama 4 Scout)
  final String _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
  // Versatile model for text tasks
  final String _textModel = 'llama-3.3-70b-versatile';

  factory AIService() {
    return _instance;
  }

  AIService._internal();

  void _initialize() {
    _apiKey = dotenv.env['GROQ_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('WARNING: GROQ_API_KEY is missing from .env file!');
      return;
    }
    _isInitialized = true;
    debugPrint(
      'AI Service Initialized with key starting with: ${_apiKey!.substring(0, 8)}...',
    );
  }

  Future<Map<String, dynamic>> analyzeWaste(Uint8List imageBytes) async {
    if (!_isInitialized) _initialize();
    if (_apiKey == null) throw Exception('AI Service (Groq) not initialized');

    try {
      return await _performAnalysis(imageBytes, _visionModel);
    } catch (e) {
      debugPrint('Primary model failed, trying stable fallback: $e');
      try {
        return await _performAnalysis(
          imageBytes,
          'llama-3.2-11b-vision-preview',
        );
      } catch (e2) {
        debugPrint('Stable fallback also failed: $e2');
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> _performAnalysis(
    Uint8List imageBytes,
    String model,
  ) async {
    final base64Image = base64Encode(imageBytes);

    final prompt = """
      Identify the waste item in this image and analyze it for segregation.
      Return ONLY a valid JSON object.
      
      JSON structure:
      {
        "type": "Specific Waste Type",
        "description": "Short summary (e.g., Plastic Bottle)",
        "detailed_analysis": "Provide a 1-2 sentence detailed description of the waste item, its material, and condition.",
        "tag": "Category (Recyclable, Organic, Hazardous, E-Waste, or Non-Recyclable)",
        "confidence": Integer (0-100),
        "disposal_instructions": ["Step-by-step instructions"],
        "recycling_options": ["Where/how to recycle"],
        "pro_tips": ["Environmental strategies"]
      }
      
      Be extremely accurate. Use your deep knowledge of waste management and environmental standards.
    """;

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.1,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('Groq API Error ($model): ${response.body}');
      throw Exception(
        "Groq API Error (${response.statusCode}): ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    return jsonDecode(content);
  }

  Future<String> _getVisualDescription(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    const visionPrompt =
        "Identify the waste items in this image. Describe their material, condition, and any brand names visible. Be very detailed about what the items are.";

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': visionPrompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
        'temperature': 0.1,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Vision API Error (${response.statusCode}): ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? "Unidentified item";
  }

  Future<String> getQuickReport(Uint8List imageBytes) async {
    if (!_isInitialized) _initialize();
    if (_apiKey == null) throw Exception('AI Service (Groq) not initialized');

    // For quick reports, we just use the vision model directly for speed
    return await _getVisualDescription(imageBytes);
  }

  Future<String> chat(String message) async {
    if (!_isInitialized) _initialize();
    if (_apiKey == null) throw Exception('AI Service (Groq) not initialized');

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _textModel,
          'messages': [
            {'role': 'user', 'content': message},
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          "Groq API Error (${response.statusCode}): ${response.body}",
        );
      }

      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } catch (e) {
      debugPrint('Groq Chat Error: $e');
      return "Error processing request";
    }
  }
}
