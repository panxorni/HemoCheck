import 'package:dart_frog/dart_frog.dart';
import 'package:hemocheck_backend/db.dart';
import 'package:hemocheck_backend/models/bloque_horario.dart';

Future<Response> onRequest(RequestContext context, String sedeId, String horarioId) async {
  final request = context.request;
  //Buscar si el bloque existe en la lista simulada
  final index = tablaHorarios.indexWhere(
        (bloque) => bloque.id == horarioId && bloque.sedeId == sedeId,
  );
  // Si index es -1, significa que no existe
  if (index == -1) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Bloque horario no encontrado'},
    );
  }
// MANEJAR LA EDICIÓN (PUT / PATCH)
  if (request.method == HttpMethod.put || request.method == HttpMethod.patch) {
    final body = await request.json() as Map<String, dynamic>;
    final bloqueAntiguo = tablaHorarios[index];

    // Crea una nueva versión mezclando los datos nuevos con los antiguos.
    // Si no enviaron un campo (es null), se conserva el valor antiguo.
    final bloqueActualizado = BloqueHorario(
      id: bloqueAntiguo.id,
      sedeId: bloqueAntiguo.sedeId,
      fecha: (body['fecha'] as String?) ?? bloqueAntiguo.fecha,
      horaInicio: (body['horaInicio'] as String?) ?? bloqueAntiguo.horaInicio,
      horaFin: (body['horaFin'] as String?) ?? bloqueAntiguo.horaFin,
      capacidadMaxima: (body['capacidadMaxima'] as int?) ?? bloqueAntiguo.capacidadMaxima,
      reservasActuales: bloqueAntiguo.reservasActuales,
    );

    // Se reemplaza el registro viejo por el nuevo en la lista
    tablaHorarios[index] = bloqueActualizado;
    return Response.json(
      body: {
        'mensaje': 'Bloque actualizado con éxito',
        'data': bloqueActualizado.toJson(),
      },
    );
  }

  // MANEJAR LA ELIMINACIÓN (DELETE)
  if (request.method == HttpMethod.delete) {
    tablaHorarios.removeAt(index);

    // 204 significa "No Content". Es el código HTTP estándar para un borrado exitoso.
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405, body: 'Método no permitido');
}