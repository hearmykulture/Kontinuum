/// Text formatting helpers shared across the app.
String formatTitleCase(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final String lower = trimmed.toLowerCase();
  final StringBuffer buffer = StringBuffer();
  bool capitalizeNext = true;

  for (final int codeUnit in lower.runes) {
    final String char = String.fromCharCode(codeUnit);
    if (capitalizeNext && _isAsciiLetter(codeUnit)) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
    } else {
      buffer.write(char);
      if (_isAsciiLetterOrDigit(codeUnit)) {
        capitalizeNext = false;
      }
    }

    if (!_isAsciiLetterOrDigit(codeUnit)) {
      capitalizeNext = true;
    }
  }

  return buffer.toString();
}

bool _isAsciiLetter(int codeUnit) =>
    (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);

bool _isAsciiDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

bool _isAsciiLetterOrDigit(int codeUnit) =>
    _isAsciiLetter(codeUnit) || _isAsciiDigit(codeUnit);
