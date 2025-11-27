/// Text similarity and duplicate detection service
class TextSimilarityService {
  /// Calculate Levenshtein distance between two strings
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    
    // Create distance matrix
    List<List<int>> matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // Calculate distances
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Calculate similarity percentage (0-100) using Levenshtein distance
  static double calculateSimilarity(String text1, String text2) {
    if (text1 == text2) return 100.0;
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    final distance = levenshteinDistance(text1.toLowerCase(), text2.toLowerCase());
    final maxLength = text1.length > text2.length ? text1.length : text2.length;
    
    return ((maxLength - distance) / maxLength) * 100;
  }

  /// Calculate Jaccard similarity using word sets
  static double jaccardSimilarity(String text1, String text2) {
    final words1 = text1.toLowerCase().split(RegExp(r'\s+'));
    final words2 = text2.toLowerCase().split(RegExp(r'\s+'));
    
    final set1 = words1.toSet();
    final set2 = words2.toSet();
    
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    
    if (union == 0) return 0.0;
    
    return (intersection / union) * 100;
  }

  /// Calculate cosine similarity using word frequency vectors
  static double cosineSimilarity(String text1, String text2) {
    final words1 = text1.toLowerCase().split(RegExp(r'\s+'));
    final words2 = text2.toLowerCase().split(RegExp(r'\s+'));
    
    // Build word frequency maps
    final freq1 = <String, int>{};
    final freq2 = <String, int>{};
    
    for (final word in words1) {
      freq1[word] = (freq1[word] ?? 0) + 1;
    }
    for (final word in words2) {
      freq2[word] = (freq2[word] ?? 0) + 1;
    }
    
    // Get all unique words
    final allWords = {...freq1.keys, ...freq2.keys};
    
    // Calculate dot product and magnitudes
    double dotProduct = 0;
    double magnitude1 = 0;
    double magnitude2 = 0;
    
    for (final word in allWords) {
      final f1 = freq1[word] ?? 0;
      final f2 = freq2[word] ?? 0;
      
      dotProduct += f1 * f2;
      magnitude1 += f1 * f1;
      magnitude2 += f2 * f2;
    }
    
    if (magnitude1 == 0 || magnitude2 == 0) return 0.0;
    
    return (dotProduct / (sqrt(magnitude1) * sqrt(magnitude2))) * 100;
  }

  /// Combined similarity score (weighted average of multiple methods)
  static double combinedSimilarity(String text1, String text2) {
    final levenshtein = calculateSimilarity(text1, text2);
    final jaccard = jaccardSimilarity(text1, text2);
    final cosine = cosineSimilarity(text1, text2);
    
    // Weighted average: Levenshtein 40%, Jaccard 30%, Cosine 30%
    return (levenshtein * 0.4) + (jaccard * 0.3) + (cosine * 0.3);
  }

  /// Check if two texts are duplicates (>85% similarity)
  static bool isDuplicate(String text1, String text2, {double threshold = 85.0}) {
    return combinedSimilarity(text1, text2) >= threshold;
  }

  /// Find similar texts from a list
  static List<SimilarityMatch> findSimilar(
    String query,
    List<String> texts, {
    double threshold = 85.0,
  }) {
    final matches = <SimilarityMatch>[];
    
    for (int i = 0; i < texts.length; i++) {
      final similarity = combinedSimilarity(query, texts[i]);
      if (similarity >= threshold) {
        matches.add(SimilarityMatch(
          index: i,
          text: texts[i],
          similarity: similarity,
        ));
      }
    }
    
    // Sort by similarity (highest first)
    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    
    return matches;
  }

  /// Normalize text for comparison (remove extra spaces, punctuation, etc.)
  static String normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
  }
}

/// Result of a similarity match
class SimilarityMatch {
  final int index;
  final String text;
  final double similarity;

  const SimilarityMatch({
    required this.index,
    required this.text,
    required this.similarity,
  });

  @override
  String toString() => 'SimilarityMatch(index: $index, similarity: ${similarity.toStringAsFixed(2)}%)';
}

// Helper function for square root
double sqrt(double x) {
  if (x < 0) return 0;
  if (x == 0) return 0;
  
  double guess = x / 2;
  double epsilon = 0.00001;
  
  while ((guess * guess - x).abs() > epsilon) {
    guess = (guess + x / guess) / 2;
  }
  
  return guess;
}
