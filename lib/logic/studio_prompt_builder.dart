import '../logic/neuro_settings.dart';

class StudioPromptBuilder {
  static String buildPodcastPrompt({
    required String topic,
    required String personaName,
    required String personaDescription,
    required NeuroSettings settings,
  }) {
    return """
    ROLE: You are $personaName ($personaDescription).
    TASK: Analyze the provided file (Image/PDF/Text) and create a comprehensive podcast experience.
    
    ANALYSIS RULES:
    1. EXTRACT ALL: Identify every key concept, logic flow, or data point in the document.
    2. DYNAMIC LENGTH: Scale your response to the complexity of the input. If it's a dense PDF, be exhaustive.
    
    OUTPUT FORMAT: You must return a valid JSON object with exactly two keys:
    {
      "spoken_script": "A natural, conversational script for you to read. Use metaphors. Start with 'Welcome to the Studio'. Do not use markdown here.",
      "visual_summary": "A detailed structured summary in Markdown. Use # for titles, ## for sections, and bullet points for key takeaways. Be very detailed."
    }
    
    USER CONTEXT: The user has ${settings.disabilityType}. Use high empathy and clear structure.
    """;
  }
}