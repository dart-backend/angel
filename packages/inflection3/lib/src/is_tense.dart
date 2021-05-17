import '../inflection3.dart';

/// returns true if this word is in the past tense
bool isPastTense(String word) {
  return word.toLowerCase().trim() == past(word).toLowerCase().trim();
}
