import 'package:cloud_firestore/cloud_firestore.dart';

class CitaException implements Exception {
  final String mensaje;
  CitaException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Datos de una reserva confirmada, para mostrarlos al donante.
class ReservaConfirmada {
  const ReservaConfirmada({
    required this.codigoReserva,
    required this.sedeId,
    required this.bloqueId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
  });

  final String codigoReserva;
  final String sedeId;
  final String bloqueId;
  final String fecha;
  final String horaInicio;
  final String horaFin;
}

/// Reserva y cancelación de citas de donantes sobre los bloques horarios
/// guardados en Cloud Firestore (HU3).
///
/// Estructura en Firestore:
/// - sedes/{sedeId}/horarios/{bloqueId}: fecha, horaInicio, horaFin,
///   capacidadMaxima, reservasActuales, inscritos (lista), cerrado
/// - citas/{citaId}: uid, donante, sedeId, bloqueId, fecha, horaInicio,
///   horaFin, codigoReserva, estado, fechaReserva
/// - usuarios/{uid}: citaActivaId (id de la cita activa o null)
class CitasService {
  static const String estadoActiva = 'activa';
  static const String estadoCancelada = 'cancelada';

  final FirebaseFirestore _db;

  // Sin argumentos usa Firebase real; los tests pasan una versión simulada.
  CitasService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _bloqueRef(
      String sedeId, String bloqueId) {
    return _db
        .collection('sedes')
        .doc(sedeId)
        .collection('horarios')
        .doc(bloqueId);
  }

  /// Reserva un cupo del bloque para el donante.
  ///
  /// [donanteId] es el uid de Firebase Auth e [identificador] el texto con el
  /// que el donante aparece en la lista de inscritos del bloque.
  /// Valida en una sola transacción: que el bloque exista y esté abierto,
  /// que haya cupo y que el donante no tenga otra cita activa; luego descuenta
  /// el cupo y crea la cita. Lanza [CitaException] si no se puede reservar.
  Future<ReservaConfirmada> reservar({
    required String donanteId,
    required String identificador,
    required String sedeId,
    required String bloqueId,
  }) async {
    final bloqueRef = _bloqueRef(sedeId, bloqueId);
    final usuarioRef = _db.collection('usuarios').doc(donanteId);
    final citaRef = _db.collection('citas').doc();
    final codigoReserva = 'HC-${citaRef.id.substring(0, 8).toUpperCase()}';

    String? error;
    Map<String, dynamic>? datosBloque;
    try {
      // La transacción devuelve el mensaje de error, o null si se reservó.
      // Si otro donante modifica el bloque al mismo tiempo, Firestore
      // reintenta la transacción, así nunca se supera la capacidad.
      error = await _db.runTransaction<String?>((tx) async {
        // 1. Lecturas (todas antes de escribir)
        final bloqueSnap = await tx.get(bloqueRef);
        final usuarioSnap = await tx.get(usuarioRef);

        final citaPrevId = usuarioSnap.data()?['citaActivaId'] as String?;
        Map<String, dynamic>? citaPrev;
        Map<String, dynamic>? bloquePrev;
        if (citaPrevId != null) {
          final citaPrevSnap =
              await tx.get(_db.collection('citas').doc(citaPrevId));
          citaPrev = citaPrevSnap.data();
          if (citaPrev != null) {
            final bloquePrevSnap = await tx.get(_bloqueRef(
              citaPrev['sedeId'] as String,
              citaPrev['bloqueId'] as String,
            ));
            bloquePrev = bloquePrevSnap.data();
          }
        }

        // 2. Validaciones
        final bloque = bloqueSnap.data();
        if (bloque == null) {
          return 'El bloque horario seleccionado no existe.';
        }
        if (bloque['cerrado'] == true) {
          return 'Este bloque horario fue cerrado por la sede.';
        }
        final inscritos = List<String>.from(bloque['inscritos'] ?? []);
        if (inscritos.contains(identificador)) {
          return 'Ya tienes una reserva en este bloque.';
        }
        if (_citaVigente(citaPrev, bloquePrev, identificador)) {
          return 'Ya tienes una cita activa. No puedes reservar otra.';
        }
        final capacidad = (bloque['capacidadMaxima'] as num).toInt();
        final reservas = ((bloque['reservasActuales'] ?? 0) as num).toInt();
        if (reservas >= capacidad) {
          return 'El bloque seleccionado no tiene cupos disponibles.';
        }

        // 3. Escrituras
        tx.set(citaRef, {
          'uid': donanteId,
          'donante': identificador,
          'sedeId': sedeId,
          'bloqueId': bloqueId,
          'fecha': bloque['fecha'],
          'horaInicio': bloque['horaInicio'],
          'horaFin': bloque['horaFin'],
          'codigoReserva': codigoReserva,
          'estado': estadoActiva,
          'fechaReserva': FieldValue.serverTimestamp(),
        });
        tx.update(bloqueRef, {
          'reservasActuales': reservas + 1,
          'inscritos': [...inscritos, identificador],
        });
        tx.set(
          usuarioRef,
          {'citaActivaId': citaRef.id},
          SetOptions(merge: true),
        );

        datosBloque = bloque;
        return null;
      });
    } catch (_) {
      throw CitaException(
          'No se pudo completar la reserva. Intenta nuevamente.');
    }

    if (error != null) throw CitaException(error);

    return ReservaConfirmada(
      codigoReserva: codigoReserva,
      sedeId: sedeId,
      bloqueId: bloqueId,
      fecha: datosBloque!['fecha'] as String,
      horaInicio: datosBloque!['horaInicio'] as String,
      horaFin: datosBloque!['horaFin'] as String,
    );
  }

  /// Cancela la reserva del donante en el bloque y libera el cupo.
  /// Lanza [CitaException] si no se puede cancelar.
  Future<void> cancelar({
    required String donanteId,
    required String identificador,
    required String sedeId,
    required String bloqueId,
  }) async {
    final bloqueRef = _bloqueRef(sedeId, bloqueId);
    final usuarioRef = _db.collection('usuarios').doc(donanteId);

    String? error;
    try {
      error = await _db.runTransaction<String?>((tx) async {
        final bloqueSnap = await tx.get(bloqueRef);
        final usuarioSnap = await tx.get(usuarioRef);

        final citaId = usuarioSnap.data()?['citaActivaId'] as String?;
        DocumentReference<Map<String, dynamic>>? citaRef;
        Map<String, dynamic>? cita;
        if (citaId != null) {
          citaRef = _db.collection('citas').doc(citaId);
          cita = (await tx.get(citaRef)).data();
        }

        final bloque = bloqueSnap.data();
        if (bloque == null) return 'El bloque ya no existe.';
        if (bloque['cerrado'] == true) {
          return 'Este bloque horario fue cerrado por la sede.';
        }
        final inscritos = List<String>.from(bloque['inscritos'] ?? []);
        if (!inscritos.contains(identificador)) {
          return 'No tienes una reserva activa en este bloque.';
        }
        final reservas = ((bloque['reservasActuales'] ?? 0) as num).toInt();

        tx.update(bloqueRef, {
          'reservasActuales': reservas > 0 ? reservas - 1 : 0,
          'inscritos': inscritos.where((i) => i != identificador).toList(),
        });
        if (citaRef != null &&
            cita != null &&
            cita['bloqueId'] == bloqueId &&
            cita['estado'] == estadoActiva) {
          tx.update(citaRef, {
            'estado': estadoCancelada,
            'fechaCancelacion': FieldValue.serverTimestamp(),
          });
          tx.set(
            usuarioRef,
            {'citaActivaId': null},
            SetOptions(merge: true),
          );
        }
        return null;
      });
    } catch (_) {
      throw CitaException('No se pudo cancelar la reserva. Intenta nuevamente.');
    }

    if (error != null) throw CitaException(error);
  }

  /// Una cita previa sigue vigente solo si está activa, el donante sigue
  /// inscrito en su bloque (la sede pudo sacarlo) y el bloque no terminó.
  static bool _citaVigente(
    Map<String, dynamic>? cita,
    Map<String, dynamic>? bloque,
    String identificador,
  ) {
    if (cita == null || cita['estado'] != estadoActiva) return false;
    if (bloque == null) return false;
    final inscritos = List<String>.from(bloque['inscritos'] ?? []);
    if (!inscritos.contains(identificador)) return false;
    return !_yaTermino(bloque['fecha'] as String?, bloque['horaFin'] as String?);
  }

  static bool _yaTermino(String? fecha, String? horaFin) {
    if (fecha == null || horaFin == null) return false;
    final fin = DateTime.tryParse('${fecha}T$horaFin:00');
    if (fin == null) return false;
    return DateTime.now().isAfter(fin);
  }
}
