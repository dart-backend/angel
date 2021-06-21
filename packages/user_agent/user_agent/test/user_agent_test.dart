// Copyright (c) 2017, thosakwe. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:user_agent_analyzer/user_agent_analyzer.dart';
import 'package:test/test.dart';

void main() {
  test('chrome', () {
    var ua = UserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36');
    expect([ua.isChrome, ua.isWebKit, ua.isSafari, ua.isDesktop, ua.isMacOS],
        everyElement(isTrue));
    expect([ua.isFirefox, ua.isIE, ua.isOpera, ua.isMobile, ua.isTablet],
        everyElement(isFalse));
    expect([
      ua.isAndroid,
      ua.isAndroidPhone,
      ua.isAndroidTablet,
      ua.isBlackberry,
      ua.isBlackberryPhone,
      ua.isBlackberryTablet,
      ua.isWindows,
      ua.isWindowsPhone,
      ua.isWindowsTablet
    ], everyElement(isFalse));

    expect(ua.cssPrefix, equals('-webkit-'));
    expect(ua.propertyPrefix, equals('webkit'));
  });
}
