class PIIMasker {
  static String mask(String input) {
    return input
        // Mask Emails
        .replaceAll(RegExp(r'\S+@\S+\.\S+'), '[EMAIL]')
        // Mask Phone Numbers
        .replaceAll(RegExp(r'\b\d{10}\b'), '[PHONE]')
        // Mask Proper Names (Captialized pairs)
        .replaceAll(RegExp(r'\b[A-Z][a-z]+ [A-Z][a-z]+\b'), '[NAME]')
        // Mask common address patterns
        .replaceAll(RegExp(r'\b\d{1,5}\s\w.\b'), '[LOCATION]');
  }
}