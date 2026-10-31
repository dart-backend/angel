# Issue 100

I'm trying to use "ResponseCache" but it seems that responseFinalizers is not being called which causes nothing to be written to the cache

Future configureServer(Angel app) async {
  //carrega o arquivo .env
  app.container.registerSingleton<AppConfig>(appConfig);  

  //connect to database
  final db = await connect(appConfig);
  app.container.registerSingleton<Connection>(db);

  //EnviaEmailService emailService = EnviaEmailService();
  //app.container.registerSingleton<EnviaEmailService>(emailService);

  //add Cross-Origin Resource Sharing (CORS) config
  var options = CorsOptions(allowedHeaders: ["*"], exposedHeaders: ["*"]);
  app.fallback(cors(options));
  //Access-Control-Allow-Headers: *

  //configure cache
  await configureCache(app);

  print("bootstrap.dart  ${appConfig.basePath} ");
  //file system config
  var fs = const LocalFileSystem();
  //routes config
  await app.configure(configureRoutes(fs));
}

Future configureCache(Angel app) async {
  // Simple instance.
  //var cache = ResponseCache();
  
  // You can also pass an invalidation timeout.
  var cache = ResponseCache(timeout: const Duration(days: 2));
  
  // Close the cache when the application closes.
  app.shutdownHooks.add((_) => cache.close());
  
  // Use `patterns` to specify which resources should be cached.
  cache.patterns.addAll([
    '/api/v1/estatistica/processo/ano',
   // RegExp(r'\.(png|jpg|gif|txt)$'),
    //Glob('public/**/*'),
  ]);
  
  // REQUIRED: The middleware that serves cached responses
 // app.use(cache.handleRequest);
  app.fallback(cache.handleRequest);
  
  // REQUIRED: The response finalizer that saves responses to the cache
  app.responseFinalizers.add(cache.responseFinalizer);
}
