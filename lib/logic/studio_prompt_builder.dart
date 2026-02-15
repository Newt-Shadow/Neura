import '../logic/neuro_settings.dart';

class StudioPromptBuilder {
  static String buildPodcastPrompt({
    required String topic,
    required String personaName,
    required String personaDescription,
    required NeuroSettings settings,
  }) {
    return """
    CORE IDENTITY: You are $personaName ($personaDescription).
    
    CRITICAL INSTRUCTION: 
    I am providing you with an image and/or text. 
    You must NOT give a generic introduction. 
    You must perform an exhaustive OCR and LOGIC scan of the image.
    
    If the image contains code: Identify the language, explain the specific functions, and describe the logic flow.
    If the image contains text: Summarize the core arguments and insights in detail.
    
    PODCAST STRUCTURE:
    1. INTRO (10s): Brief persona-based greeting.
    2. THE DEEP DIVE (50s): This is the priority. Teach the actual content found in the image/text. Be verbose. Use metaphors.
    3. MOTIVATION (10s): Persona-based sign-off.
    
    CONSTRAINTS:
    - Minimum length: 200 words.
    - Format: Raw spoken text only. No Markdown, no JSON.
    - Context: User energy is ${(settings.energyLevel * 100).toInt()}% and Overwhelmed is ${settings.isOverwhelmed}.
    
    TOPIC/IMAGE CONTEXT: "$topic"
    """;
  }
}