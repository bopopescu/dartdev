// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of _interceptors;

/**
 * The interceptor class for [String]. The compiler recognizes this
 * class as an interceptor, and changes references to [:this:] to
 * actually use the receiver of the method, which is generated as an extra
 * argument added to each member.
 */
class JSString implements String {
  const JSString();

  int charCodeAt(index) {
    if (index is !num) throw new ArgumentError(index);
    if (index < 0) throw new RangeError.value(index);
    if (index >= length) throw new RangeError.value(index);
    return JS('int', r'#.charCodeAt(#)', this, index);
  }

  Iterable<Match> allMatches(String str) {
    checkString(str);
    return allMatchesInStringUnchecked(this, str);
  }

  String concat(String other) {
    if (other is !String) throw new ArgumentError(other);
    return JS('String', r'# + #', this, other);
  }

  bool endsWith(String other) {
    checkString(other);
    int otherLength = other.length;
    if (otherLength > length) return false;
    return other == substring(length - otherLength);
  }

  String replaceAll(Pattern from, String to) {
    checkString(to);
    return stringReplaceAllUnchecked(this, from, to);
  }

  String replaceAllMapped(Pattern from, String convert(Match match)) {
    return this.splitMapJoin(from, onMatch: convert);
  }

  String splitMapJoin(Pattern from,
                      {String onMatch(Match match),
                       String onNonMatch(String nonMatch)}) {
    return stringReplaceAllFuncUnchecked(this, from, onMatch, onNonMatch);
  }

  String replaceFirst(Pattern from, String to) {
    checkString(to);
    return stringReplaceFirstUnchecked(this, from, to);
  }

  List<String> split(Pattern pattern) {
    checkNull(pattern);
    if (pattern is String) {
      return JS('=List', r'#.split(#)', this, pattern);
    } else if (pattern is JSSyntaxRegExp) {
      var re = regExpGetNative(pattern);
      return JS('=List', r'#.split(#)', this, re);
    } else {
      throw "String.split(Pattern) UNIMPLEMENTED";
    }
  }

  List<String> splitChars() {
    return JS('=List', r'#.split("")', this);
  }

  bool startsWith(String other) {
    checkString(other);
    int otherLength = other.length;
    if (otherLength > length) return false;
    return JS('bool', r'# == #', other,
              JS('String', r'#.substring(0, #)', this, otherLength));
  }

  String substring(int startIndex, [int endIndex]) {
    checkNum(startIndex);
    if (endIndex == null) endIndex = length;
    checkNum(endIndex);
    if (startIndex < 0 ) throw new RangeError.value(startIndex);
    if (startIndex > endIndex) throw new RangeError.value(startIndex);
    if (endIndex > length) throw new RangeError.value(endIndex);
    return JS('String', r'#.substring(#, #)', this, startIndex, endIndex);
  }

  String slice([int startIndex, int endIndex]) {
    int start, end;
    if (startIndex == null) {
      start = 0;
    } else if (startIndex is! int) {
      throw new ArgumentError("startIndex is not int");
    } else if (startIndex >= 0) {
      start = startIndex;
    } else {
      start = this.length + startIndex;
    }
    if (start < 0 || start > this.length) {
      throw new RangeError(
          "startIndex out of range: $startIndex (length: $length)");
    }
    if (endIndex == null) {
      end = this.length;
    } else if (endIndex is! int) {
      throw new ArgumentError("endIndex is not int");
    } else if (endIndex >= 0) {
      end = endIndex;
    } else {
      end = this.length + endIndex;
    }
    if (end < 0 || end > this.length) {
      throw new RangeError(
          "endIndex out of range: $endIndex (length: $length)");
    }
    if (end < start) {
      throw new ArgumentError(
          "End before start: $endIndex < $startIndex (length: $length)");
    }
    return JS('String', '#.substring(#, #)', this, start, end);
  }


  String toLowerCase() {
    return JS('String', r'#.toLowerCase()', this);
  }

  String toUpperCase() {
    return JS('String', r'#.toUpperCase()', this);
  }

  String trim() {
    return JS('String', r'#.trim()', this);
  }

  List<int> get charCodes  {
    List<int> result = new List<int>.fixedLength(length);
    for (int i = 0; i < length; i++) {
      result[i] = JS('int', '#.charCodeAt(#)', this, i);
    }
    return result;
  }

  int indexOf(String other, [int start = 0]) {
    checkNull(other);
    if (start is !int) throw new ArgumentError(start);
    if (other is !String) throw new ArgumentError(other);
    if (start < 0) return -1;
    return JS('int', r'#.indexOf(#, #)', this, other, start);
  }

  int lastIndexOf(String other, [int start]) {
    checkNull(other);
    if (other is !String) throw new ArgumentError(other);
    if (start != null) {
      if (start is !num) throw new ArgumentError(start);
      if (start < 0) return -1;
      if (start >= length) {
        if (other == "") return length;
        start = length - 1;
      }
    } else {
      start = length - 1;
    }
    return stringLastIndexOfUnchecked(this, other, start);
  }

  bool contains(String other, [int startIndex = 0]) {
    checkNull(other);
    return stringContainsUnchecked(this, other, startIndex);
  }

  bool get isEmpty => length == 0;

  int compareTo(String other) {
    if (other is !String) throw new ArgumentError(other);
    return this == other ? 0
      : JS('bool', r'# < #', this, other) ? -1 : 1;
  }

  // Note: if you change this, also change the function [S].
  String toString() => this;

  /**
   * This is the [Jenkins hash function][1] but using masking to keep
   * values in SMI range.
   *
   * [1]: http://en.wikipedia.org/wiki/Jenkins_hash_function
   */
  int get hashCode {
    // TODO(ahe): This method shouldn't have to use JS. Update when our
    // optimizations are smarter.
    int hash = 0;
    for (int i = 0; i < length; i++) {
      hash = 0x1fffffff & (hash + JS('int', r'#.charCodeAt(#)', this, i));
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash = JS('int', '# ^ (# >> 6)', hash, hash);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) <<  3));
    hash = JS('int', '# ^ (# >> 11)', hash, hash);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  Type get runtimeType => String;

  int get length => JS('int', r'#.length', this);

  String operator [](int index) {
    if (index is !int) throw new ArgumentError(index);
    if (index >= length || index < 0) throw new RangeError.value(index);
    return JS('String', '#[#]', this, index);
  }
}
