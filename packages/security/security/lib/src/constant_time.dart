/// Compares [a] and [b] in a time that does not depend on where they differ,
/// so that a secret (a signature or token) cannot be guessed one character at
/// a time.
bool equalsInConstantTime(String a, String b) {
  var diff = a.length ^ b.length;
  for (var i = 0; i < a.length && i < b.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
