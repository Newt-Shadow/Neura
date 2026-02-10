enum AIResponseType { question, plan }

class AIResponse {
  final AIResponseType type;
  final String message;
  final List<dynamic>? actions;
  final List<String>? options; // <--- NEW: Stores dynamic MCQs
  final Map<String, String>? profileUpdates;

  AIResponse({
    required this.type,
    required this.message,
    this.actions,
    this.options,
    this.profileUpdates,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      type: json['type'] == 'options' ? AIResponseType.question : AIResponseType.plan, // 'options' = question type
      message: json['question'] ?? json['motivation'] ?? json['content'] ?? "Ready?",
      actions: json['actions'], // For Plans
      options: json['options'] != null ? List<String>.from(json['options']) : null, // For MCQs
      profileUpdates: json['learnings'] != null 
          ? Map<String, String>.from(json['learnings']) 
          : null,
    );
  }
}