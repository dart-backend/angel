# user_agent
Simple Dart user agent detection library.

Runs anywhere.

Incorporates some code from the old `package:r2d2`.

```dart
main() async {
    app.get('/', (req, res) async {
        var ua = new UserAgent(req.headers.value('user-agent'));

        if (ua.isChrome) {
            res.redirect('/upgrade-your-browser');
            return;
        } else {
            // ...
        }
    });
}
```