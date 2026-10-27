import 'dart:async';

import 'package:angel3_cors/angel3_cors.dart';
import 'package:angel3_framework/angel3_framework.dart';

Future configureServer(Angel app) async {
  // The default options allow CORS from any origin, without credentials.
  // Combined with `fallback`, you can enable CORS application-wide.
  app.fallback(cors());

  // You can also enable CORS for a single route.
  app.get(
    '/my_api',
    chain([
      cors(),
      (req, res) {
        // Request handling logic here...
      },
    ]),
  );

  // Likewise, you can apply CORS to a group.
  app.chain([cors()]).group('/api', (router) {
    router.get('/version', (req, res) => 'v0');
  });

  // Of course, you can configure CORS.
  // The following is just a subset of the available options;
  app
      .chain([
        cors(
          CorsOptions(
            origin: 'https://pub.dev',
            successStatus: 200, // default 204
            allowedHeaders: ['Content-Type', 'Authorization'],
            preflightContinue: false, // default false
          ),
        ),
      ])
      .group('/configured', (router) {
        router.post('/items', (req, res) => 'created');
      });

  // You can specify the origin in different ways:
  CorsOptions(origin: 'https://pub.dev');
  CorsOptions(origin: ['https://example.org', 'http://foo.bar']);
  CorsOptions(origin: RegExp(r'^https://[a-z]+\.example\.org$'));
  CorsOptions(origin: (String s) => s.endsWith('.example.org'));
  // Browsers refuse credentials with '*': list the origins instead.
  CorsOptions(origin: ['https://app.example.org'], credentials: true);

  // Lastly, you can dynamically configure CORS, e.g. from the configuration.
  app
      .chain([
        dynamicCors((req, res) {
          var origins = app.configuration['cors_origins'] as List? ?? const [];
          return CorsOptions(origin: [for (var o in origins) o.toString()]);
        }),
      ])
      .group('/dynamic', (router) {
        router.get('/status', (req, res) => 'ok');
      });
}
