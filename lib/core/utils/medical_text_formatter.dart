/// Utility to sanitize and format medical text returned by AI models.
/// Prevents unparsed LaTeX expressions (e.g. $\\ge 1 \\text{ mm}$) from cluttering the UI.
class MedicalTextFormatter {
  static String clean(String raw) {
    if (raw.isEmpty) return raw;
    var text = raw;

    // 1. Remove LaTeX font styling wrappers (\text{...}, \mathrm{...}, \mathbf{...}, etc.)
    text = text.replaceAllMapped(RegExp(r'\\(?:text|mathrm|mathbf|mathit|textsf)\{([^}]*)\}'), (m) => m.group(1) ?? '');

    // 2. Common LaTeX math and medical symbols
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

    // 3. LaTeX fractions: \frac{a}{b} -> a/b
    text = text.replaceAllMapped(RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'), (m) => '${m.group(1)}/${m.group(2)}');

    // 4. Remove dollar signs used around math/unit expressions
    // Handle double dollars $$...$$
    text = text.replaceAllMapped(RegExp(r'\$\$(.*?)\$\$', dotAll: true), (m) => m.group(1)?.trim() ?? '');
    // Handle single dollars $...$
    text = text.replaceAllMapped(RegExp(r'\$(.*?)\$'), (m) => m.group(1)?.trim() ?? '');

    // 5. Clean escaped punctuation that markdown doesn't need
    text = text.replaceAll(r'\%', '%');
    text = text.replaceAll(r'\_', '_');

    // 6. Clean multiple spaces inside words caused by removal of \text{}
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    return text.trim();
  }
}

