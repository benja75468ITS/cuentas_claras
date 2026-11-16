import 'dart:convert';
import 'package:http/http.dart' as http;

/// Consume la API pública Frankfurter (tipos de cambio del BCE, sin API key).
class DivisasService {
  static const monedas = ['MXN', 'USD', 'EUR', 'GBP', 'CAD'];

  static final Map<String, ({double tasa, DateTime fecha})> _cache = {};
  static const _ttl = Duration(minutes: 10);

  static Future<double> tasa(String de, String a) async {
    final origen = de.trim().toUpperCase();
    final destino = a.trim().toUpperCase();
    if (origen == destino) return 1.0;

    final clave = '$origen->$destino';
    final enCache = _cache[clave];
    if (enCache != null && DateTime.now().difference(enCache.fecha) < _ttl) {
      return enCache.tasa;
    }

    final url = Uri.https('api.frankfurter.dev', '/v1/latest', {
      'base': origen,
      'symbols': destino,
    });
    final r = await http.get(url).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error HTTP ${r.statusCode}');

    final j = jsonDecode(r.body);
    final rates = j is Map<String, dynamic> ? j['rates'] : null;
    final valor = rates is Map<String, dynamic> ? rates[destino] : null;
    if (valor is! num || valor <= 0) {
      throw Exception('Tipo de cambio inválido para $origen -> $destino');
    }

    final resultado = valor.toDouble();
    _cache[clave] = (tasa: resultado, fecha: DateTime.now());
    return resultado;
  }
}
