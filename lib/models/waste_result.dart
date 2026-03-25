class WasteResult {
  final String type;
  final String description;
  final String detailedAnalysis;
  final String tag;
  final int confidence;
  final List<String> disposalInstructions;
  final List<String> recyclingOptions;
  final List<String> proTips;

  WasteResult({
    required this.type,
    required this.description,
    required this.detailedAnalysis,
    required this.tag,
    required this.confidence,
    required this.disposalInstructions,
    required this.recyclingOptions,
    required this.proTips,
  });

  factory WasteResult.fromMap(Map<String, dynamic> data) {
    // Handle nested structures from the new schema
    final itemObj = data['item'] as Map<String, dynamic>? ?? {};
    final classification = data['classification'] as Map<String, dynamic>? ?? {};
    final guidance = data['guidance'] as Map<String, dynamic>? ?? {};

    return WasteResult(
      type: itemObj['type'] ?? data['type'] ?? 'Unknown',
      description: itemObj['description'] ?? data['description'] ?? 'No description available',
      detailedAnalysis: itemObj['detailedAnalysis'] ?? data['detailedAnalysis'] ?? '',
      tag: classification['tag'] ?? data['tag'] ?? 'waste',
      confidence: _parseInt(classification['confidence'] ?? data['confidence']),
      disposalInstructions: List<String>.from(
        guidance['disposalInstructions'] ?? data['disposalInstructions'] ?? data['dis_instructions'] ?? [],
      ),
      recyclingOptions: List<String>.from(
        guidance['recyclingOptions'] ?? data['recyclingOptions'] ?? [],
      ),
      proTips: List<String>.from(
        guidance['proTips'] ?? data['proTips'] ?? [],
      ),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
