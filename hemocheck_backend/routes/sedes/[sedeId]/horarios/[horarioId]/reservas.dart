import 'package:dart_frog/dart_frog.dart';
import 'package:hemocheck_backend/db.dart';
import 'package:hemocheck_backend/models/bloque_horario.dart';
import 'package:hemocheck_backend/models/cita.dart';

/// POST /sedes/{sedeId}/horarios/{horarioId}/reservas
/// Cuerpo: {"donanteId": "<uid del donante en Firebase>"}
Future<Response> onRequest(
    RequestContext context,
    String sedeId,
    String horarioId,
    ) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Método no permitido');
  }

  Map<String, dynamic>? body;
  try {
    body = await request.json() as Map<String, dynamic>;
  } catch (_) {
    body = null;
  }

  final donanteId = body?['donanteId'];
  if (donanteId is! String || donanteId.trim().isEmpty) {
    return _error(400, 'Falta el identificador del donante.');
  }

  // Desde aquí no hay ningún "await": la validación y la actualización se
  // ejecutan sin interrupciones, así dos reservas simultáneas no pueden
  // tomar el mismo último cupo.
  final index = tablaHorarios.indexWhere(
        (b) => b.id == horarioId && b.sedeId == sedeId,
  );
  if (index == -1) {
    return _error(404, 'El bloque horario seleccionado no existe.');
  }

  final tieneCitaActiva = tablaCitas.any(
        (c) => c.donanteId == donanteId && c.estaActiva,
  );
  if (tieneCitaActiva) {
    return _error(409, 'Ya tienes una cita activa. No puedes reservar otra.');
  }

  final bloque = tablaHorarios[index];
  if (!bloque.tieneCapacidad) {
    return _error(409, 'El bloque seleccionado no tiene cupos disponibles.');
  }

  tablaHorarios[index] = BloqueHorario(
    id: bloque.id,
    sedeId: bloque.sedeId,
    fecha: bloque.fecha,
    horaInicio: bloque.horaInicio,
    horaFin: bloque.horaFin,
    capacidadMaxima: bloque.capacidadMaxima,
    reservasActuales: bloque.reservasActuales + 1,
  );

  final ahora = DateTime.now();
  final cita = Cita(
    id: 'cita-${ahora.microsecondsSinceEpoch}-${tablaCitas.length + 1}',
    donanteId: donanteId,
    sedeId: sedeId,
    bloqueId: horarioId,
    fechaReserva: ahora.toIso8601String(),
  );
  tablaCitas.add(cita);

  return Response.json(statusCode: 201, body: cita.toJson());
}

Response _error(int statusCode, String mensaje) {
  return Response.json(statusCode: statusCode, body: {'error': mensaje});
}