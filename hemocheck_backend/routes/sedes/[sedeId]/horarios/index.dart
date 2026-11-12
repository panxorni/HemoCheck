import 'package:dart_frog/dart_frog.dart';
import 'package:hemocheck_backend/db.dart';
import 'package:hemocheck_backend/models/bloque_horario.dart';

Future<Response> onRequest(RequestContext context, String sedeId) async {
  final request = context.request;

  if (request.method == HttpMethod.options) {
    return Response(statusCode: 204, headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
    });
  }
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;

    final capacidad = body["capacidadMaxima"] as int?;
    if (capacidad == null || capacidad <= 0) {
      return Response.json(
        statusCode: 400,
        body: {"error": "Error de validación: La capacidad máxima debe ser mayor a 0."},
      );
    }
    try {
      body['sedeId'] = sedeId;
      body['id'] = body['id'] ?? DateTime
          .now()
          .millisecondsSinceEpoch
          .toString();

      final nuevoBloque = BloqueHorario.fromJson(body);
      tablaHorarios.add(nuevoBloque);

      return Response.json(statusCode: 201, body: nuevoBloque.toJson());
    }catch(e){
      return Response.json(
        statusCode: 500,
        body: {"error": "Error interno al procesar el bloque: $e"},
      );
    }
  }
  if (request.method == HttpMethod.get) {
    //simulacion de select de base de datos
    final resultados = tablaHorarios
        .where((b) => b.sedeId == sedeId)
        .map((b) => b.toJson()).toList();
    return Response.json(body: resultados);
  }
  return Response(statusCode: 405, body: 'Método no permitido');
}