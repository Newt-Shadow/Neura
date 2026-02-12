// lib/domain/ai_response.dart

class MicroStep {
  final int stepId;
  final String instruction;
  final int estimatedSeconds;

  MicroStep({
    required this.stepId,
    required this.instruction,
    required this.estimatedSeconds,
  });

  factory MicroStep.fromJson(Map<String, dynamic> json) {
    return MicroStep(
      stepId: json['step_id'] ?? 0,
      instruction: json['instruction'] ?? "Take a breath.",
      estimatedSeconds: json['estimated_seconds'] ?? 30,
    );
  }
}

class AIResponse {
  final String mode; // single_step | multi_step | clarification

  final String missionName;
  final String coachingMessage;
  final List<MicroStep> actions;

  final String? question;
  final List<String>? options;

  AIResponse({
    required this.mode,
    required this.missionName,
    required this.coachingMessage,
    required this.actions,
    this.question,
    this.options,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      mode: json['mode'] ?? "single_step",
      missionName: json['mission_name'] ?? "New Quest",
      coachingMessage: json['coaching_message'] ?? "You've got this.",
      actions: (json['actions'] as List? ?? [])
          .map((e) => MicroStep.fromJson(e))
          .toList(),
      question: json['question'],
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : null,
    );
  }
}
