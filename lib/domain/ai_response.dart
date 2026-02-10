enum AIResponseType { question, plan }

class AIResponse {
  final AIResponseType type;
  final String message; // The question OR the motivation
  final List<dynamic>? actions; // Null if it's just a question
  final Map<String, String>? profileUpdates; // New facts learned about user

  AIResponse({
    required this.type,
    required this.message,
    this.actions,
    this.profileUpdates,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      type: json['type'] == 'question' ? AIResponseType.question : AIResponseType.plan,
      message: json['content'] ?? "Let's do this!",
      actions: json['plan']?['actions'],
      profileUpdates: json['learnings'] != null 
          ? Map<String, String>.from(json['learnings']) 
          : null,
    );
  }
}