enum AIResponseType { question, plan }

class AIResponse {
  final AIResponseType type;
  final String message;
  final List<dynamic>? actions;
  final List<String>? options;
  final List<int>? box2d; // [ymin, xmin, ymax, xmax]
  final Map<String, String>? profileUpdates;

  AIResponse({
    required this.type,
    required this.message,
    this.actions,
    this.options,
    this.box2d,
    this.profileUpdates,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      type: json['type'] == 'options' ? AIResponseType.question : AIResponseType.plan,
      message: json['question'] ?? json['message'] ?? json['motivation'] ?? "Ready.",
      actions: json['actions'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      box2d: json['box_2d'] != null ? List<int>.from(json['box_2d']) : null,
      profileUpdates: json['learnings'] != null ? Map<String, String>.from(json['learnings']) : null,
    );
  }
}