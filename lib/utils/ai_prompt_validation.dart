/// Fail-fast validation for AI prompts. Throws if prompt too short.
void validatePromptLength(String prompt, {String fieldName = 'Input'}) {
  if (prompt.trim().length < 3) {
    throw Exception('Please enter at least 3 characters');
  }
}
