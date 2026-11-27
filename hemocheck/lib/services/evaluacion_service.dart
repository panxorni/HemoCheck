import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hemocheck/models/cita.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/utils/evaluacion_validators.dart';

/// Estados posibles de una cita para el flujo de asistencia y evaluación.
enum EstadoCita { activa, realizada, noAsistio }

/// Excepción personalizada para errores de reglas de negocio en la evaluación.
class EvaluacionException implements Exception {
  final String message;
  const EvaluacionException(this.message);

  @override
  String toString() => 'EvaluacionException: $message';
}

class EvaluacionService {
  final FirebaseFirestore _firestore;

  EvaluacionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Registra la asistencia de una cita (solo realizada o noAsistio).
  Future<void> registrarAsistencia(
      String citaId,
      EstadoCita nuevoEstado,
      ) async {
    if (nuevoEstado != EstadoCita.realizada &&
        nuevoEstado != EstadoCita.noAsistio) {
      throw const EvaluacionException(
        'Estado de asistencia inválido. Solo se permite realizada o noAsistio.',
      );
    }

    try {
      await _firestore.collection('citas').doc(citaId).update({
        'estado': nuevoEstado.name,
      });
    } catch (e) {
      throw EvaluacionException('Error al registrar asistencia: $e');
    }
  }

  /// Valida reglas clínicas, actualiza datos del donante y guarda la evaluación.
  Future<Evaluacion> registrarEvaluacion({
    required Cita cita,
    required DateTime fechaNacimientoDonante,
    required double pesoKg,
    required TipoSangre tipoSangre,
    required bool autorizacionParental,
    required ResultadoEvaluacion resultado,
    DateTime? fechaHabilitacion,
    required String profesionalId,
  }) async {
    // Regla 1: La cita debe estar marcada como 'realizada'
    if (cita.estado != EstadoCita.realizada.name) {
      throw const EvaluacionException(
        'No se puede evaluar una cita cuya asistencia no esté como realizada.',
      );
    }

    // Regla 2: Validaciones de EvaluacionValidators antes de persistir
    final errorPeso = EvaluacionValidators.validatePeso(pesoKg.toString());
    if (errorPeso != null) {
      throw EvaluacionException(errorPeso);
    }

    final errorEdad =
    EvaluacionValidators.validateEdadMinima(fechaNacimientoDonante);
    if (errorEdad != null) {
      throw EvaluacionException(errorEdad);
    }

    final errorAutorizacion = EvaluacionValidators.validateAutorizacionParental(
      fechaNacimientoDonante,
      autorizacionParental,
    );
    if (errorAutorizacion != null) {
      throw EvaluacionException(errorAutorizacion);
    }

    final errorFechaHabilitacion =
    EvaluacionValidators.validateFechaHabilitacion(
      resultado,
      fechaHabilitacion,
    );
    if (errorFechaHabilitacion != null) {
      throw EvaluacionException(errorFechaHabilitacion);
    }

    // Regla 3: Actualizar peso y tipoSangre en colección 'donantes' (por RUT / donanteId)
    await _firestore.collection('donantes').doc(cita.donanteId).set(
      {
        'pesoKg': pesoKg,
        'tipoSangre': tipoSangre.name,
      },
      SetOptions(merge: true),
    );

    // Regla 4: Guardar el documento de Evaluacion en 'evaluaciones'
    final evaluacion = Evaluacion(
      citaId: cita.id,
      donanteRut: cita.donanteId,
      profesionalId: profesionalId,
      fecha: DateTime.now(),
      resultado: resultado,
      fechaHabilitacion: resultado == ResultadoEvaluacion.diferidoTemporal
          ? fechaHabilitacion
          : null,
    );

    await _firestore.collection('evaluaciones').add(evaluacion.toJson());

    return evaluacion;
  }
}