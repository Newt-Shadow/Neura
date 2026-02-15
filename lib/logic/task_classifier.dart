class TaskClassifier {
  // 🧠 COGNITIVE: Requires focus, decision making, or mental effort
  static final Set<String> _cognitiveKeywords = {
    'decide', 'plan', 'choose', 'think', 'analyze', 'review', 'study', 'learn',
    'write', 'draft', 'edit', 'code', 'debug', 'calculate', 'budget', 'read',
    'research', 'search', 'find', 'locate', 'compare', 'organize', 'sort',
    'prioritize', 'schedule', 'list', 'brainstorm', 'solve', 'check'
  };

  // 💪 PHYSICAL: Requires movement, motor skills, or sensory engagement
  static final Set<String> _physicalKeywords = {
    'clean', 'wash', 'scrub', 'wipe', 'sweep', 'mop', 'vacuum', 'dust',
    'fold', 'hang', 'put', 'place', 'move', 'carry', 'lift', 'pack', 'unpack',
    'tidy', 'declutter', 'throw', 'discard', 'fix', 'repair', 'build', 'assemble',
    'cook', 'chop', 'boil', 'fry', 'eat', 'drink', 'go', 'walk', 'run', 'exercise',
    'stretch', 'shower', 'brush', 'dress', 'wear'
  };

  // 🗣️ SOCIAL: Requires communication, empathy, or overcoming social anxiety
  static final Set<String> _socialKeywords = {
    'call', 'phone', 'email', 'text', 'message', 'dm', 'reply', 'respond',
    'ask', 'tell', 'say', 'speak', 'meet', 'visit', 'invite', 'share', 'post',
    'upload', 'present', 'explain', 'listen', 'thank', 'apologize'
  };

  static TaskType classify(String text) {
    final lowerText = text.toLowerCase();
    
    // 1. Tokenize (Split into words) & Clean
    final words = lowerText.replaceAll(RegExp(r'[^\w\s]'), '').split(' ');

    int cognitiveScore = 0;
    int physicalScore = 0;
    int socialScore = 0;

    // 2. Score the sentence based on keyword matches
    for (var word in words) {
      // Simple Stemming: Remove 'ing', 's', 'ed' to match root words
      String root = word;
      if (root.endsWith('ing')) root = root.substring(0, root.length - 3);
      else if (root.endsWith('ed')) root = root.substring(0, root.length - 2);
      else if (root.endsWith('s')) root = root.substring(0, root.length - 1);

      if (_cognitiveKeywords.contains(root) || _cognitiveKeywords.contains(word)) cognitiveScore++;
      if (_physicalKeywords.contains(root) || _physicalKeywords.contains(word)) physicalScore++;
      if (_socialKeywords.contains(root) || _socialKeywords.contains(word)) socialScore++;
    }

    // 3. Determine Dominant Category
    if (socialScore > 0) return TaskType.social; // Social usually takes priority (highest anxiety)
    if (physicalScore > cognitiveScore) return TaskType.physical;
    if (cognitiveScore > physicalScore) return TaskType.cognitive;
    
    // Default fallback if ambiguous
    return TaskType.general;
  }
}

enum TaskType { cognitive, physical, social, general }