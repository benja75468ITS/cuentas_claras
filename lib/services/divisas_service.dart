import 'dart:convert';
import 'package:http/http.dart' as http;

/// Consume la API pública Frankfurter (tipos de cambio del BCE, sin API key).
class DivisasService {
  static const monedas = ['MXN', 'USD', 'EUR', 'GBP', 'CAD'];

  static Future<double> tasa(String de, String a) async {
    if (de == a) return 1;
    final url = Uri.https('api.frankfurter.dev', '/v1/latest', {'base': de, 'symbols': a});
    final r = await http.get(url).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error ${r.statusCode}');
    final j = jsonDecode(r.body);
    return (j['rates'][a] as num).toDouble();
  }
}
