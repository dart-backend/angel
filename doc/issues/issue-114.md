# Issue 114

serious performance problem on the Angel router when using chain and group to group routes and apply the same Middleware
with just one route defined I can get 13767.22 requests per second

isaque@pmro174330:~/wrk-cmm$ ./wrk -t12 -c400 -d30s <http://192.168.66.123:3350/>
Running 30s test @ <http://192.168.66.123:3350/>
  12 threads and 400 connections
  Thread Stats   Avg     Stdev       Max       Min   +/- Stdev
    Latency    28.76ms   10.43ms   91.30ms    1.71ms   73.37%
    Req/Sec     1.15k    72.07      2.22k   585.00     72.95%
  413532 requests in 30.04s, 105.71MB read
Requests/sec:  13767.22
Transfer/sec:      3.52MB

with 122 defined routes grouped using chain and group I only get 156.68 requests per second

unable to record first byte metrics
unabe to record last byte metrics 1699474363297116 - 1699474361169768 = 2127348
unable to record first byte metrics
unabe to record last byte metrics 1699474363320014 - 1699474361217196 = 2102818
unable to record first byte metrics
  Thread Stats   Avg     Stdev       Max       Min   +/- Stdev
    Latency     1.55s   442.53ms    2.00s   146.73ms   82.66%
    Req/Sec    16.79     12.38    160.00      0.00     74.18%
  4716 requests in 30.10s, 1.23MB read
  Socket errors: connect 0, read 0, write 465, timeout 3522
Requests/sec:    156.68
Transfer/sec:     41.93KB

If I don't use chain and group, and only use addRoute, passing the suffix concatenated with the path and the middleware, performance improves a lot, reaching 3487.82 requests per second

isaque@pmro174330:~/wrk-cmm$ ./wrk -t12 -c400 -d30s <http://192.168.66.123:3350/>
Running 30s test @ <http://192.168.66.123:3350/>
  12 threads and 400 connections
  Thread Stats   Avg     Stdev       Max       Min   +/- Stdev
    Latency   112.15ms   30.61ms  451.83ms   29.18ms   90.85%
    Req/Sec   296.09     40.34    505.00      1.00     80.06%
  104819 requests in 30.05s, 26.80MB read
  Socket errors: connect 0, read 0, write 638, timeout 0
Requests/sec:   3487.82
Transfer/sec:      0.89MB

minimal app to reproduce the issue

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';
import 'package:angel3_cors/angel3_cors.dart';
import 'dart:convert';
import 'package:file/file.dart' as file;
import 'package:angel3_static/angel3_static.dart' as static_file_server;
import 'dart:async';
import 'package:file/local.dart';

//dart ./bin/main.dart -p 3350 -a 0.0.0.0 -j 4
main(List<String> args) async {
  return Runner('angel', configureServer).run(args);
}

Future configureServer(Angel app) async {
  final options = CorsOptions();
  app.fallback(cors(options));
  final fs = const LocalFileSystem();
  await app.configure(configureRoutes(fs));
}

AngelConfigurer configureRoutes(file.FileSystem fileSystem) {
  return (Angel app) {
    app.get('/', (req, res) => res.write('angel'));

    app.chain([simulatedMiddleware]).group('/api/v1', (router) {
      for (final sr in simulatedRoutes) {
        final method = sr.keys.first.toUpperCase();
        final path = sr.values.first;
        router.addRoute(method, path, (req, res) => simulatedWork);
      }
    });

    // for (final sr in simulatedRoutes) {
    //   final method = sr.keys.first.toUpperCase();
    //   final path = sr.values.first;
    //   app.addRoute(method, '/api/v1' + path, (req, res) => simulatedWork,middleware: [simulatedMiddleware]);
    // }

    if (!app.environment.isProduction) {
      var vDir = static_file_server.VirtualDirectory(
        app,
        fileSystem,
        source: fileSystem.directory('storage'),
      );
      app.fallback(vDir.handleRequest);
    }

    app.fallback((req, res) {
      res.headers['Content-Type'] = 'application/json;charset=utf-8';
      res.statusCode = 404;
      return res.write(jsonEncode({
        'message': 'Rota não existe',
        'exception': 'Rota não existe',
        'stackTrace': ''
      }));
    });

    final oldErrorHandler = app.errorHandler;
    app.errorHandler = (e, req, res) async {
      if (req.accepts('text/html', strict: true)) {
        if (e.statusCode == 404 && req.accepts('text/html', strict: true)) {
          await res
              .render('error', {'message': 'Arquivo não existe ${req.uri}.'});
        } else {
          await res.render('error', {'message': e.message});
        }
      } else {
        return await oldErrorHandler(e, req, res);
      }
    };
  };
}

final simulatedRoutes = [
  {'get': '/administracao/paises'},
  {'get': '/administracao/ufs'},
  {'get': '/administracao/municipios'},
  {'get': '/administracao/modulos'},
  {'get': '/administracao/permissoes/:numCgm/:anoExercicio'},
  {'put': '/administracao/permissoes/:numCgm/:anoExercicio'},
  {'get': '/administracao/escolaridades'},
  {'get': '/administracao/tiposlogradouro'},
  {'get': '/administracao/orgaos'},
  {'get': '/administracao/unidades'},
  {'get': '/administracao/departamentos'},
  {'get': '/administracao/setores'},
  {'get': '/administracao/gestao'},
  {'get': '/administracao/usuarios'},
  {'get': '/administracao/usuarios/:numcgm'},
  {'post': '/administracao/usuarios'},
  {'put': '/administracao/usuarios'},
  {'get': '/administracao/cgm'},
  {'get': '/administracao/cgm/:cgm'},
  {'get': '/administracao/auditorias'},
  {'post': '/administracao/auditorias'},
  {'get': '/administracao/configuracao'},
  {'get': '/administracao/configuracao/by/filtro'},
  {'get': '/administracao/funcionalidades'},
  {'get': '/administracao/menu/:cgm'},
  {'get': '/administracao/organograma/hierarquia'},
  {'get': '/administracao/acoes'},
  //auth
  {'post': '/change/pass'},
  {'get': '/auth/check/permissao/:cgm'},
  {'post': '/auth/login'},
  {'post': '/auth/check'},
  {'get': '/auth/check/toke'},
  //cgm
  {'get': '/cgm/full'},
  {'get': '/cgm/full/:cgm'},
  {'delete': '/cgm'},
  {'post': '/cgm/full'},
  {'post': '/cgm/full/interno'},
  {'put': '/cgm/full'},
  {'get': '/cgm/atributos'},
  {'get': '/cgm/atributos/:cgm'},
  {'get': '/cgm/categoriashabilitacao'},
  {'get': '/cgm/tiposlogradouro'},
  //
  {'get': '/estatistica/processos/ano'},
  {'get': '/estatistica/processos/periodo/setor/primero/tramite'},
  {'get': '/estatistica/processos/situacao'},
  {'get': '/estatistica/processos/classificacao'},
  {'get': '/estatistica/processos/assunto'},
  //
  {'get': '/norma/normas'},
  //
  {'get': '/protocolo/processos/favoritos/cgm/:cgm'},
  {'post': '/protocolo/processos/favoritos'},
  {'post': '/protocolo/processos/favoritos/:codProcesso/:anoExercicio'},
  {'put': '/protocolo/processos/favoritos'},
  {'delete': '/protocolo/processos/favoritos/:id'},
  {'delete': '/protocolo/processos/favoritos/:codProcesso/:anoExercicio'},
  {'get': '/protocolo/acoes/favoritas/cgm/:cgm'},
  {'post': '/protocolo/acoes/favoritas'},
  {'post': '/protocolo/acoes/favoritas/:codAcao'},
  {'put': '/protocolo/acoes/favoritas'},
  {'delete': '/protocolo/acoes/favoritas/:id'},
  {'delete': '/protocolo/acoes/favoritas/:codAcao'},
  {'get': '/protocolo/assuntos'},
  {'post': '/protocolo/assuntos'},
  {'put': '/protocolo/assuntos'},
  {'delete': '/protocolo/assuntos'},
  {'get': '/protocolo/assuntos/:codAssunto/:codClassificacao'},
  {'get': '/protocolo/classificacoes'},
  {'post': '/protocolo/classificacoes'},
  {'put': '/protocolo/classificacoes'},
  {'delete': '/protocolo/classificacoes'},
  {'get': '/protocolo/despachospadrao'},
  {'post': '/protocolo/despachospadrao'},
  {'put': '/protocolo/despachospadrao'},
  {'delete': '/protocolo/despachospadrao'},
  {'get': '/protocolo/tramites'},
  {'post': '/protocolo/tramites'},
  {
    'put':
        '/protocolo/tramites/:codClassiOld/:codAssuntoOld/:ordemOld/:exercicioOld'
  },
  {'delete': '/protocolo/tramites'},
  {'get': '/protocolo/processos/:anoExercicio/:codProcesso'},
  {'get': '/protocolo/processos/em/apenso/:anoExercicio/:codProcesso'},
  {'get': '/protocolo/processos/apenso/a/:anoExercicio/:codProcesso'},
  {'get': '/protocolo/processos/andamentos/:anoExercicio/:codProcesso'},
  {
    'get':
        '/protocolo/processos/despachos/:anoExercicio/:codProcesso/:codAndamento/:codUsuario/:timestamp'
  },
  {'get': '/protocolo/processos'},
  {'get': '/protocolo/processos/areceber'},
  {'get': '/protocolo/processos/aemcaminhar'},
  {'get': '/protocolo/processos/byfiltros'},
  {'get': '/protocolo/processos/aapensara'},
  {'get': '/protocolo/processos/adesapensar'},
  {'get': '/protocolo/processos/adespachar'},
  {'get': '/protocolo/processos/aalterar'},
  {'get': '/protocolo/processos/acancelar'},
  {'get': '/protocolo/processos/aarquivar'},
  {'get': '/protocolo/processos/adesarquivar'},
  {'post': '/protocolo/processos'},
  {'post': '/protocolo/processos/implantar'},
  {'put': '/protocolo/processos'},
  {'post': '/protocolo/processos/receber/lote'},
  {'post': '/protocolo/processos/despachar/lote'},
  {'post': '/protocolo/processos/encaminhar/lote'},
  {'post': '/protocolo/processos/cancelarencaminhamento/lote'},
  {'post': '/protocolo/processos/apensar/lote'},
  {'post': '/protocolo/processos/desapensar/lote'},
  {'post': '/protocolo/processos/arquivar/lote'},
  {'post': '/protocolo/processos/desarquivar/lote'},
  {'post': '/protocolo/processos/anexos'},
  {'get': '/protocolo/processos/anexos/:codProcesso/:anoExercicio'},
  {'get': '/protocolo/situacoes'},
  {'get': '/protocolo/historicoarquivamento'},
  {'post': '/protocolo/historicoarquivamento'},
  {'put': '/protocolo/historicoarquivamento'},
  {'delete': '/protocolo/historicoarquivamento'},
  {'get': '/protocolo/listagemprocessos'},
  {'post': '/protocolo/listagemprocessos'},
  {'get': '/protocolo/documentos'},
  {'post': '/protocolo/documentos'},
  {'put': '/protocolo/documentos'},
  {'delete': '/protocolo/documentos'},
  {'get': '/protocolo/atributosprotocolo'},
  {'post': '/protocolo/atributosprotocolo'},
  {'put': '/protocolo/atributosprotocolo'},
  {'delete': '/protocolo/atributosprotocolo'},
  {'get': '/protocolo/processos/public/site/:anoExercicio/:codProcesso'},
];

Future<dynamic> simulatedWork(RequestContext req, ResponseContext res) async {
  try {
    // ignore: unused_local_variable
    final filters = req.queryParameters;
    final listItems = List.generate(150, (int index) => {'name': 'Jon_$index'});
    res.statusCode = 200;
    res.headers['Content-Type'] = 'application/json;charset=utf-8';
    res.headers['total-records'] = '150';
    res.write(jsonEncode(listItems));
  } catch (e, s) {
    print('simulatedWork@all $e $s');
    var v = jsonEncode({
      'is_error': true,
      'status_code': 400,
      'message': 'Error',
      'exception': e.toString(),
      'stackTrace': s.toString()
    });
    res.statusCode = 400;
    res.headers['Content-Type'] = 'application/json;charset=utf-8';
    res.write(v);
  }
}

Future<bool> simulatedMiddleware(
    RequestContext req, ResponseContext res) async {
  try {
    return true;
  } catch (e, s) {
    print('simulatedMiddleware: $s $s');
    throw AngelHttpException.notAuthenticated(message: '$e $s');
  }
}
