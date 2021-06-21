# User Agent Analyzer

[![version](https://img.shields.io/badge/pub-v3.0.0-brightgreen)](https://pub.dartlang.org/packages/user_agent_analyzer)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/user_agent/user_agent/LICENSE)

**Forked from `user_agent` to support NNBD**

A library to identify the type of devices and web browsers based on `User-Agent` string.

Runs anywhere.

```dart
void main() async {
    app.get('/', (req, res) async {
        var ua = UserAgent(req.headers.value('user-agent'));

        if (ua.isChrome) {
            res.redirect('/upgrade-your-browser');
            return;
        } else {
            // ...
        }
    });
}
```
