import 'package:dart_frog/dart_frog.dart';
import 'package:hemocheck_backend/db.dart';
import 'package:hemocheck_backend/models/bloque_horario.dart';

Future<Response> onRequest(RequestContext context, String sedeId) async {
  final request = context.request;

  if (request.method == HttpMethod.get) {
    //simulacion de select de base de datos
    final resultados = tablaHorarios
        .where((b) => b.sedeId == sedeId)
        .map((b) => b.toJson()).toList();
    return Response.json(body: resultados);
  }

  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    body['sedeId'] = sedeId;
    body['id'] = body['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    final nuevoBloque = BloqueHorario.fromJson(body);
    tablaHorarios.add(nuevoBloque);

    return Response.json(statusCode: 201, body: nuevoBloque.toJson());
  }
  return Response(statusCode: 405, body: 'Método no permitido');
}