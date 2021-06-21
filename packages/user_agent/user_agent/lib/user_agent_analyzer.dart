library user_agent_analyzer;

/// Utils for device detection.
class UserAgent {
  bool _isChrome = false;
  bool _isOpera = false;
  bool _isIE = false;
  bool _isFirefox = false;
  bool _isWebKit = false;
  String? _cachedCssPrefix;
  String? _cachedPropertyPrefix;

  final String value, _lowerValue;

  static const List<String> knownMobileUserAgentPrefixes = [
    'w3c ',
    'w3c-',
    'acs-',
    'alav',
    'alca',
    'amoi',
    'audi',
    'avan',
    'benq',
    'bird',
    'blac',
    'blaz',
    'brew',
    'cell',
    'cldc',
    'cmd-',
    'dang',
    'doco',
    'eric',
    'hipt',
    'htc_',
    'inno',
    'ipaq',
    'ipod',
    'jigs',
    'kddi',
    'keji',
    'leno',
    'lg-c',
    'lg-d',
    'lg-g',
    'lge-',
    'lg/u',
    'maui',
    'maxo',
    'midp',
    'mits',
    'mmef',
    'mobi',
    'mot-',
    'moto',
    'mwbp',
    'nec-',
    'newt',
    'noki',
    'palm',
    'pana',
    'pant',
    'phil',
    'play',
    'port',
    'prox',
    'qwap',
    'sage',
    'sams',
    'sany',
    'sch-',
    'sec-',
    'send',
    'seri',
    'sgh-',
    'shar',
    'sie-',
    'siem',
    'smal',
    'smar',
    'sony',
    'sph-',
    'symb',
    't-mo',
    'teli',
    'tim-',
    'tosh',
    'tsm-',
    'upg1',
    'upsi',
    'vk-v',
    'voda',
    'wap-',
    'wapa',
    'wapi',
    'wapp',
    'wapr',
    'webc',
    'winw',
    'winw',
    'xda ',
    'xda-'
  ];

  static const List<String> knownMobileUserAgentKeywords = [
    'blackberry',
    'webos',
    'ipod',
    'lge vx',
    'midp',
    'maemo',
    'mmp',
    'mobile',
    'netfront',
    'hiptop',
    'nintendo DS',
    'novarra',
    'openweb',
    'opera mobi',
    'opera mini',
    'palm',
    'psp',
    'phone',
    'smartphone',
    'symbian',
    'up.browser',
    'up.link',
    'wap',
    'windows ce'
  ];

  static const List<String> knownTabletUserAgentKeywords = [
    'ipad',
    'playbook',
    'hp-tablet',
    'kindle'
  ];

  UserAgent(this.value) : _lowerValue = value.toLowerCase();

  /// Determines if the user agent string contains the desired string. Case-insensitive.
  bool contains(String needle) => _lowerValue.contains(needle.toLowerCase());

  bool get isDesktop => isMacOS || (!isMobile && !isTablet);

  bool get isTablet => knownTabletUserAgentKeywords.any(contains);

  bool get isMobile => knownMobileUserAgentKeywords.any(contains);

  bool get isMacOS => contains('Macintosh') || contains('Mac OS X');

  bool get isSafari => contains('Safari');

  bool get isAndroid => contains('android');

  bool get isAndroidPhone => contains('android') && contains('mobile');

  bool get isAndroidTablet => contains('android') && !contains('mobile');

  bool get isWindows => contains('windows');

  bool get isWindowsPhone => isWindows && contains('phone');

  bool get isWindowsTablet => isWindows && contains('touch');

  bool get isBlackberry =>
      contains('blackberry') || contains('bb10') || contains('rim');

  bool get isBlackberryPhone => isBlackberry && !contains('tablet');

  bool get isBlackberryTablet => isBlackberry && contains('tablet');

  /// Determines if the current device is running Chrome.
  bool get isChrome {
    _isChrome = value.contains('Chrome', 0);
    return _isChrome;
  }

  /// Determines if the current device is running Opera.
  bool get isOpera {
    _isOpera = value.contains('Opera', 0);
    return _isOpera;
  }

  /// Determines if the current device is running Internet Explorer.
  bool get isIE {
    _isIE = !isOpera && value.contains('Trident/', 0);
    return _isIE;
  }

  /// Determines if the current device is running Firefox.
  bool get isFirefox {
    _isFirefox = value.contains('Firefox', 0);
    return _isFirefox;
  }

  /// Determines if the current device is running WebKit.
  bool get isWebKit {
    _isWebKit = !isOpera && value.contains('WebKit', 0);
    return _isWebKit;
  }

  /// Gets the CSS property prefix for the current platform.
  String get cssPrefix {
    var prefix = _cachedCssPrefix;
    if (prefix != null) return prefix;
    if (isFirefox) {
      prefix = '-moz-';
    } else if (isIE) {
      prefix = '-ms-';
    } else if (isOpera) {
      prefix = '-o-';
    } else {
      prefix = '-webkit-';
    }
    return _cachedCssPrefix = prefix;
  }

  /// Prefix as used for JS property names.
  String get propertyPrefix {
    var prefix = _cachedPropertyPrefix;
    if (prefix != null) return prefix;
    if (isFirefox) {
      prefix = 'moz';
    } else if (isIE) {
      prefix = 'ms';
    } else if (isOpera) {
      prefix = 'o';
    } else {
      prefix = 'webkit';
    }
    return _cachedPropertyPrefix = prefix;
  }
}
