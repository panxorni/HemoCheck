import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hemocheck/models/bloque_horario.dart';

Future<List<BloqueHorario>> obtenerHorarios(String sedeId) async {
  final url = Uri.parse('http://10.0.2.2:8080/sedes/$sedeId/horarios');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List<dynamic> datos = jsonDecode(response.body);
    return datos.map((json) => BloqueHorario.fromJson(json)).toList();
  } else {
    throw Exception('Error al cargar horarios: ${response.statusCode}');
  }
}