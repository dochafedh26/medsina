/// Utility to sanitize and format medical text and explanations.
/// Cleans raw LaTeX math expressions, HTML tags (spans, fonts, details),
/// entities and ensures beautiful Markdown rendering.
class MedicalTextFormatter {
  static String clean(String raw) {
    if (raw.isEmpty) return raw;
    var text = raw;

    // 0. Clean escaped apostrophes & HTML entities
    text = text.replaceAll(r'\x27', "'");
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&apos;', "'");

    // 1. Remove details / summary wrapper tags
    text = text.replaceAll(RegExp(r'</?(?:details|summary)[^>]*>', caseSensitive: false), '');

    // 2. Convert styled spans: bold ones to **...**, others to inner text
    text = text.replaceAllMapped(
      RegExp(r'<span[^>]*font-weight:\s*bold[^>]*>(.*?)</span>', caseSensitive: false, dotAll: true),
      (m) => '**${m.group(1)?.trim()}**',
    );
    text = text.replaceAllMapped(
      RegExp(r'<span[^>]*>(.*?)</span>', caseSensitive: false, dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // Cleanup any lingering open or close span tags
    text = text.replaceAll(RegExp(r'</?span[^>]*>', caseSensitive: false), '');

    // 3. Convert HTML bold/italic/break tags to Markdown
    text = text.replaceAllMapped(
      RegExp(r'<(?:b|strong)>(.*?)</(?:b|strong)>', caseSensitive: false, dotAll: true),
      (m) => '**${m.group(1)?.trim()}**',
    );
    text = text.replaceAllMapped(
      RegExp(r'<(?:i|em)>(.*?)</(?:i|em)>', caseSensitive: false, dotAll: true),
      (m) => '*${m.group(1)?.trim()}*',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</?(?:u|small|mark|font|div|p|section)[^>]*>', caseSensitive: false), '');

    // 4. Remove LaTeX font styling wrappers (\text{...}, \mathrm{...}, \mathbf{...}, etc.)
    text = text.replaceAllMapped(RegExp(r'\\(?:text|mathrm|mathbf|mathit|textsf)\{([^}]*)\}'), (m) => m.group(1) ?? '');

    // 5. Common LaTeX math and medical symbols
    text = text.replaceAll(RegExp(r'\\(?:ge|geq)\b'), '≥');
    text = text.replaceAll(RegExp(r'\\(?:le|leq)\b'), '≤');
    text = text.replaceAll(RegExp(r'\\pm\b'), '±');
    text = text.replaceAll(RegExp(r'\\times\b'), '×');
    text = text.replaceAll(RegExp(r'\\cdot\b'), '·');
    text = text.replaceAll(RegExp(r'\\div\b'), '÷');
    text = text.replaceAll(RegExp(r'\\approx\b'), '≈');
    text = text.replaceAll(RegExp(r'\\neq\b'), '≠');
    text = text.replaceAll(RegExp(r'\\(?:rightarrow|to)\b'), '→');
    text = text.replaceAll(RegExp(r'\\leftarrow\b'), '←');
    text = text.replaceAll(RegExp(r'\\leftrightarrow\b'), '↔');
    text = text.replaceAll(RegExp(r'\\uparrow\b'), '↑');
    text = text.replaceAll(RegExp(r'\\downarrow\b'), '↓');
    text = text.replaceAll(RegExp(r'\\(?:mu\s*g|mug)\b'), 'µg');
    text = text.replaceAll(RegExp(r'\\mu\b'), 'µ');
    text = text.replaceAll(RegExp(r'\\alpha\b'), 'α');
    text = text.replaceAll(RegExp(r'\\beta\b'), 'β');
    text = text.replaceAll(RegExp(r'\\gamma\b'), 'γ');
    text = text.replaceAll(RegExp(r'\\delta\b'), 'δ');
    text = text.replaceAll(RegExp(r'\\infty\b'), '∞');
    text = text.replaceAll(RegExp(r'\\(?:circ|degree)\b'), '°');
    text = text.replaceAll(RegExp(r'\^\s*\\circ'), '°');

    // 6. LaTeX fractions: \frac{a}{b} -> a/b
    text = text.replaceAllMapped(RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'), (m) => '${m.group(1)}/${m.group(2)}');

    // 7. Remove dollar signs used around math/unit expressions
    text = text.replaceAllMapped(RegExp(r'\$\$(.*?)\$\$', dotAll: true), (m) => m.group(1)?.trim() ?? '');
    text = text.replaceAllMapped(RegExp(r'\$(.*?)\$'), (m) => m.group(1)?.trim() ?? '');

    // 8. Clean escaped punctuation that markdown doesn't need
    text = text.replaceAll(r'\%', '%');
    text = text.replaceAll(r'\_', '_');

    // 9. Clean excessive duplicate bold markers (e.g. ****word**** -> **word**)
    text = text.replaceAll(RegExp(r'\*{4,}'), '**');
    text = text.replaceAll(RegExp(r'\*\*\s*\*\*'), '');

    // 10. Ensure tables have a blank line preceding them so Markdown parsers render them
    text = text.replaceAllMapped(
      RegExp(r'([^\n])\n(\|[^\n]+\|\n\|[-:\s|]+\|)'),
      (m) => '${m.group(1)}\n\n${m.group(2)}',
    );

    // 11. Clean multiple spaces inside words
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    return text.trim();
  }
}
