import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String mensaje;
  ApiException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Datos de conexión guardados en el teléfono.
class Ajustes {
  String url;
  String apiKey;
  String nombre;

  Ajustes({this.url = '', this.apiKey = '', this.nombre = ''});

  bool get completo => url.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  static Future<Ajustes> cargar() async {
    final p = await SharedPreferences.getInstance();
    return Ajustes(
      url: p.getString('url') ?? '',
      apiKey: p.getString('apiKey') ?? '',
      nombre: p.getString('nombre') ?? '',
    );
  }

  Future<void> guardar() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('url', url.trim());
    await p.setString('apiKey', apiKey.trim());
    await p.setString('nombre', nombre.trim());
  }
}

/// Cliente de la API del backend de facturación.
class Api {
  final Ajustes ajustes;
  Api(this.ajustes);

  static const _timeout = Duration(seconds: 90);

  Uri _uri(String ruta, [Map<String, String>? query]) {
    var base = ajustes.url.trim();
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final uri = Uri.parse('$base$ruta');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'X-API-Key': ajustes.apiKey.trim(),
        'Content-Type': 'application/json; charset=utf-8',
      };

  dynamic _decodificar(http.Response r) {
    dynamic cuerpo;
    try {
      cuerpo = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      cuerpo = null;
    }
    if (r.statusCode >= 400) {
      if (cuerpo is Map && cuerpo['error'] != null) {
        throw ApiException(cuerpo['error'].toString());
      }
      if (r.statusCode == 401) throw ApiException('Clave de API incorrecta');
      throw ApiException('Error del servidor (${r.statusCode})');
    }
    return cuerpo;
  }

  Future<dynamic> _get(String ruta, [Map<String, String>? query]) async {
    try {
      final r = await http.get(_uri(ruta, query), headers: _headers).timeout(_timeout);
      return _decodificar(r);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder');
    } catch (e) {
      throw ApiException('No se pudo conectar con el servidor. Revisá la dirección y la red.');
    }
  }

  Future<dynamic> _post(String ruta, Map<String, dynamic> datos) async {
    try {
      final r = await http
          .post(_uri(ruta), headers: _headers, body: jsonEncode(datos))
          .timeout(_timeout);
      return _decodificar(r);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder');
    } catch (e) {
      throw ApiException('No se pudo conectar con el servidor. Revisá la dirección y la red.');
    }
  }

  Future<Map<String, dynamic>> salud() async =>
      Map<String, dynamic>.from(await _get('/salud'));

  Future<Map<String, dynamic>> resumen() async =>
      Map<String, dynamic>.from(await _get('/api/resumen'));

  Future<List<Map<String, dynamic>>> documentos({String? estado, int limite = 30, int offset = 0}) async {
    final q = <String, String>{'limite': '$limite', 'offset': '$offset'};
    if (estado != null) q['estado'] = estado;
    final lista = await _get('/api/documentos', q) as List;
    return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> detalle(String cdc) async =>
      Map<String, dynamic>.from(await _get('/api/documentos/$cdc'));

  Future<Map<String, dynamic>> emitir(Map<String, dynamic> documento) async =>
      Map<String, dynamic>.from(await _post('/api/documentos', documento));

  Future<Map<String, dynamic>> cancelar(String cdc, String motivo) async =>
      Map<String, dynamic>.from(await _post('/api/documentos/$cdc/cancelar', {'motivo': motivo}));

  Future<void> reenviarPendientes() async => _post('/api/reenviar-pendientes', {});

  Future<Map<String, dynamic>> consultarRuc(String ruc) async =>
      Map<String, dynamic>.from(await _get('/api/ruc/$ruc'));

  Future<Uint8List> kude(String cdc) async {
    try {
      final r = await http
          .get(_uri('/api/documentos/$cdc/kude.pdf'), headers: _headers)
          .timeout(_timeout);
      if (r.statusCode != 200) {
        _decodificar(r);
        throw ApiException('No se pudo obtener el KuDE');
      }
      return r.bodyBytes;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('No se pudo descargar el KuDE');
    }
  }
}
