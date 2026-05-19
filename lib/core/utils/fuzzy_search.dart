import 'dart:math';

/// Utility class for fuzzy string matching
/// Supports typo-tolerant search (e.g., "Mria" matches "Maria")
class FuzzySearch {
  /// Calculate Levenshtein distance between two strings
  /// The number of single-character edits needed to change one word into another
  static int levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final m = s1.length;
    final n = s2.length;
    
    // Use two rows instead of full matrix for space optimization
    var prevRow = List<int>.filled(n + 1, 0);
    var currRow = List<int>.filled(n + 1, 0);

    // Initialize first row
    for (var j = 0; j <= n; j++) {
      prevRow[j] = j;
    }

    for (var i = 1; i <= m; i++) {
      currRow[0] = i;
      
      for (var j = 1; j <= n; j++) {
        final cost = s1[i - 1].toLowerCase() == s2[j - 1].toLowerCase() ? 0 : 1;
        
        currRow[j] = [
          prevRow[j] + 1,      // deletion
          currRow[j - 1] + 1,  // insertion
          prevRow[j - 1] + cost, // substitution
        ].reduce(min);
      }
      
      // Swap rows
      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
    }

    return prevRow[n];
  }

  /// Calculate normalized similarity score (0.0 to 1.0)
  /// 1.0 = exact match, 0.0 = completely different
  static double similarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1.0;
    
    final distance = levenshteinDistance(s1.toLowerCase(), s2.toLowerCase());
    return 1.0 - (distance / maxLen);
  }

  /// Check if query matches target with fuzzy tolerance
  /// [threshold] determines how strict the match is (default 0.6 = 60% similar)
  static bool isFuzzyMatch(String query, String target, {double threshold = 0.6}) {
    if (query.isEmpty) return true;
    if (target.isEmpty) return false;
    
    final q = query.toLowerCase().trim();
    final t = target.toLowerCase().trim();
    
    // Exact substring match always wins
    if (t.contains(q)) return true;
    
    // Check if query is contained in any word of target
    final words = t.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.contains(q)) return true;
      if (similarity(q, word) >= threshold) return true;
    }
    
    // Check overall similarity for short queries
    if (q.length <= 3) {
      return words.any((w) => w.startsWith(q));
    }
    
    return similarity(q, t) >= threshold;
  }

  /// Score a match for sorting (higher = better match)
  /// Returns 0 if no match, higher values for better matches
  static int matchScore(String query, String target) {
    if (query.isEmpty) return 1;
    if (target.isEmpty) return 0;
    
    final q = query.toLowerCase().trim();
    final t = target.toLowerCase().trim();
    
    // Exact match gets highest score
    if (t == q) return 1000;
    
    // Starts with query
    if (t.startsWith(q)) return 900;
    
    // Contains query as word
    if (t.contains(' $q') || t.contains('$q ')) return 800;
    
    // Contains query anywhere
    if (t.contains(q)) return 700;
    
    // Fuzzy match with high similarity
    final sim = similarity(q, t);
    if (sim >= 0.8) return 600;
    if (sim >= 0.7) return 500;
    if (sim >= 0.6) return 400;
    
    // Word-level fuzzy matches
    final words = t.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.startsWith(q)) return 350;
      if (similarity(q, word) >= 0.8) return 300;
      if (similarity(q, word) >= 0.7) return 200;
      if (similarity(q, word) >= 0.6) return 100;
    }
    
    return 0;
  }

  /// Filter and sort a list based on fuzzy search
  /// Returns items that match the query, sorted by relevance
  static List<T> filterAndSort<T>(
    String query,
    List<T> items,
    String Function(T) getSearchableText, {
    double threshold = 0.6,
  }) {
    if (query.isEmpty) return items;
    
    final scored = <_ScoredItem<T>>[];
    
    for (final item in items) {
      final text = getSearchableText(item);
      final score = matchScore(query, text);
      
      if (score > 0) {
        scored.add(_ScoredItem(item, score));
      }
    }
    
    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));
    
    return scored.map((s) => s.item).toList();
  }

  /// Filter list keeping only matches (unsorted)
  static List<T> filter<T>(
    String query,
    List<T> items,
    String Function(T) getSearchableText, {
    double threshold = 0.6,
  }) {
    if (query.isEmpty) return items;
    
    return items.where((item) {
      final text = getSearchableText(item);
      return isFuzzyMatch(query, text, threshold: threshold);
    }).toList();
  }
}

class _ScoredItem<T> {
  final T item;
  final int score;
  
  _ScoredItem(this.item, this.score);
}

/// Extension for convenient fuzzy matching on strings
extension FuzzyString on String {
  /// Check if this string fuzzy-matches the query
  bool fuzzyMatch(String query, {double threshold = 0.6}) {
    return FuzzySearch.isFuzzyMatch(query, this, threshold: threshold);
  }
  
  /// Get similarity score to another string (0.0 to 1.0)
  double similarityTo(String other) {
    return FuzzySearch.similarity(this, other);
  }
}
