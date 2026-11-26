/// Helper functions to performantly transform strings, without `RegExp`.
library;

/// Removes every leading and trailing occurrence of [needle] from
/// [haystack], as `haystack.replaceAll(RegExp('^($needle)+|($needle)+\$'), '')`
/// does with [needle] escaped, but without a `RegExp`.
///
/// A [haystack] of nothing but [needle]s gives `''`, and an empty [needle]
/// gives [haystack] unchanged.
String stripStray(String haystack, String needle) {
  var n = needle.length;
  if (n == 0) return haystack;
  var start = 0, end = haystack.length;
  while (start + n <= end && haystack.startsWith(needle, start)) {
    start += n;
  }
  while (end - n >= start && _endsWithAt(haystack, needle, end)) {
    end -= n;
  }
  return start == 0 && end == haystack.length
      ? haystack
      : haystack.substring(start, end);
}

/// Whether [needle] ends at index [end] of [haystack].
bool _endsWithAt(String haystack, String needle, int end) {
  if (needle.length == 1) {
    return haystack.codeUnitAt(end - 1) == needle.codeUnitAt(0);
  }
  return haystack.startsWith(needle, end - needle.length);
}

/// Removes the leading and trailing slashes of [str], as
/// `str.replaceAll(RegExp(r'(^/+)|(/+$)'), '')` does, but about 40 times
/// faster. Only slashes gives `''`.
String stripStraySlashes(String str) {
  var start = 0, end = str.length;
  while (start < end && str.codeUnitAt(start) == 0x2F) {
    start++;
  }
  while (end > start && str.codeUnitAt(end - 1) == 0x2F) {
    end--;
  }
  return start == 0 && end == str.length ? str : str.substring(start, end);
}

/// Removes the leading and trailing escaped slashes (`\/`) of [str].
String stripRegexStraySlashes(String str) => stripStray(str, '\\/');
