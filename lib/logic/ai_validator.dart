// lib/logic/ai_validator.dart

import '../domain/ai_response.dart';

class AIValidator {

  static AIResponse validate(AIResponse response) {

    // -----------------------------
    // Clarification must have options
    // -----------------------------
    if (response.mode == "clarification") {

      if (response.options == null || response.options!.isEmpty) {
        return AIResponse(
          mode: "clarification",
          missionName: "Clarification Needed",
          coachingMessage: "",
          actions: [],
          question: response.question ?? "What would you like to do?",
          options: [
            "Start cleaning",
            "Organize this space",
            "Begin a task here",
            "I will type my goal"
          ],
        );
      }

      // Enforce exactly 4 options
      if (response.options!.length > 4) {
        return AIResponse(
          mode: "clarification",
          missionName: response.missionName,
          coachingMessage: response.coachingMessage,
          actions: [],
          question: response.question,
          options: response.options!.take(4).toList(),
        );
      }
    }

    // -----------------------------
    // Task must have actions
    // -----------------------------
    if (response.mode != "clarification" &&
        response.actions.isEmpty) {

      return AIResponse(
        mode: "clarification",
        missionName: "Clarification Needed",
        coachingMessage: "",
        actions: [],
        question: "I need a clearer goal.",
        options: [
          "Clean this area",
          "Organize items",
          "Start something here",
          "I will type my goal"
        ],
      );
    }

    return response;
  }
}
