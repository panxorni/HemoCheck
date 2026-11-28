import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hemocheck/models/donacion.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/models/unidad_sangre.dart';
import 'package:hemocheck/utils/donacion_validators.dart';

/// Excepción de dominio lanzada cuando una operación de registro de donación
/// incumple alguna regla de negocio o falla en su persistencia atómica.
class DonacionException implements Exception {
  /// Crea una [DonacionException] con el [mensaje] descriptivo del error.
  DonacionException(this.mensaje);

  /// Descripción legible del motivo del rechazo o fallo.
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Encapsula el resultado completo de un registro de donación exitoso.
///
/// Agrupa los tres artefactos generados de forma conjunta: la [donacion]
/// clínica (RF-20), la [unidad] creada en el stock con vencimiento a 42 días
/// (RF-21) y el [registroBitacora] de auditoría (RNF-07).
class ResultadoRegistroDonacion {
  /// Crea una instancia inmutable con los artefactos del registro.
  const ResultadoRegistroDonacion(
    this.donacion,
    this.unidad,
    this.registroBitacora,
  );

  /// Registro clínico de la extracción efectuada.
  final Donacion donacion;

  /// Unidad de sangre generada automáticamente para el inventario de la sede.
  final UnidadSangre unidad;

  /// Entrada de trazabilidad con usuario, acción, código de bolsa y fecha/hora.
  final Map<String, dynamic> registroBitacora;
}

/// Tipo de función auxiliar para inyectar una estrategia personalizada de
/// persistencia atómica durante pruebas unitarias.
typedef PersistenciaAtomicaCallback =
    Future<void> Function(ResultadoRegistroDonacion resultado);

/// Servicio de negocio responsable de verificar la aptitud del donante (CU-17),
/// registrar la donación (CU-16), generar la unidad en stock (CU-18) y dejar
/// constancia en bitácora (RNF-07) de manera atómica.
class DonacionService {
  /// Crea una instancia de [DonacionService].
  ///
  /// En producción, sin argumentos, utiliza [FirebaseFirestore.instance] de
  /// forma diferida al momento de persistir. En pruebas unitarias se puede
  /// inyectar un [db] simulado o un callback [persistirAtomicamente] sin
  /// requerir la inicialización de Firebase.
  DonacionService({
    FirebaseFirestore? db,
    PersistenciaAtomicaCallback? persistirAtomicamente,
  }) : _db = db,
       _persistirAtomicamente = persistirAtomicamente;

  final FirebaseFirestore? _db;
  final PersistenciaAtomicaCallback? _persistirAtomicamente;

  FirebaseFirestore get _firestore => _db ?? FirebaseFirestore.instance;

  /// Verifica si el donante cuenta con una evaluación clínica en estado
  /// [ResultadoEvaluacion.apto] vigente (RF-19, CU-17).
  ///
  /// Lanza [DonacionException] en cualquiera de los siguientes escenarios:
  /// - [evaluacion] es `null` (sin evaluación registrada, escenario 1').
  /// - [Evaluacion.resultado] es [ResultadoEvaluacion.diferidoTemporal]
  ///   (escenario 2', informando la fecha de habilitación).
  /// - [Evaluacion.resultado] es [ResultadoEvaluacion.rechazadoPermanente]
  ///   (escenario 2'').
  void verificarEstadoAptoVigente(Evaluacion? evaluacion) {
    if (evaluacion == null) {
      throw DonacionException('El donante no tiene evaluación registrada.');
    }
    if (evaluacion.resultado == ResultadoEvaluacion.diferidoTemporal) {
      throw DonacionException(
        'Donante diferido hasta ${evaluacion.fechaHabilitacion}.',
      );
    }
    if (evaluacion.resultado == ResultadoEvaluacion.rechazadoPermanente) {
      throw DonacionException('Donante rechazado permanentemente.');
    }
  }

  /// Valida todas las reglas de negocio de CU-16 y construye en memoria la
  /// [Donacion], la [UnidadSangre] (+42 días) y el mapa de bitácora sin
  /// ejecutar escritura en base de datos.
  ResultadoRegistroDonacion prepararRegistroDonacion({
    required Evaluacion? evaluacion,
    required TipoSangre? tipoSangre,
    required bool yaExisteDonacionEnCita,
    required int volumenMl,
    required String sedeId,
    required String profesionalId,
    DateTime? fecha,
  }) {
    // 1. Verificación obligatoria de estado apto vigente (RF-19, CU-17).
    verificarEstadoAptoVigente(evaluacion);

    // 2. Verificación de tipo de sangre registrado (escenario 3' de CU-16).
    if (tipoSangre == null) {
      throw DonacionException(
        'El donante no tiene tipo de sangre registrado. Debe registrarse antes de continuar.',
      );
    }

    // 3. Prevención de duplicidad de donación por cita (escenario 5' de CU-16).
    if (yaExisteDonacionEnCita) {
      throw DonacionException(
        'Ya existe una donación registrada para esta cita.',
      );
    }

    // 4. Validación de volumen extraído (RF-20, escenario 4' de CU-16).
    if (volumenMl <= 0) {
      throw DonacionException('El volumen donado debe ser mayor a 0 ml.');
    }
    if (volumenMl > DonacionValidators.volumenMaximoMl) {
      throw DonacionException(
        'El volumen donado no puede superar los ${DonacionValidators.volumenMaximoMl} ml.',
      );
    }

    final fechaExtraccion = fecha ?? DateTime.now();

    final donacion = Donacion(
      id: 'DON-${fechaExtraccion.millisecondsSinceEpoch}',
      citaId: evaluacion!.citaId,
      donanteRut: evaluacion.donanteRut,
      sedeId: sedeId,
      profesionalId: profesionalId,
      volumenMl: volumenMl,
      fecha: fechaExtraccion,
    );

    // Generación automática de la unidad en inventario con +42 días (RF-21, CU-18).
    final unidad = UnidadSangre.desdeDonacion(
      donacion: donacion,
      tipoSangre: tipoSangre,
    );

    // Registro de trazabilidad requerido por RNF-07.
    final registroBitacora = <String, dynamic>{
      'usuarioId': profesionalId,
      'accion': 'REGISTRAR_DONACION',
      'fechaHora': fechaExtraccion.toIso8601String(),
      'codigoBolsa': unidad.codigoBolsa,
    };

    return ResultadoRegistroDonacion(donacion, unidad, registroBitacora);
  }

  /// Ejecuta el flujo completo de registro de donación (CU-16 + CU-18 + RNF-07)
  /// y persiste los tres documentos de forma atómica en Firestore.
  ///
  /// Si [yaExisteDonacionEnCita] no se proporciona, consulta previamente en la
  /// colección `donaciones` si ya existe un registro asociado a
  /// [Evaluacion.citaId].
  ///
  /// Utiliza un [WriteBatch] de Firestore para guardar simultáneamente los
  /// documentos en `donaciones`, `unidades_sangre` y `bitacora`. Si la
  /// escritura falla, Firestore revierte la operación completa y el método
  /// lanza [DonacionException] (escenario 7' de CU-16).
  Future<ResultadoRegistroDonacion> registrarDonacion({
    required Evaluacion? evaluacion,
    required TipoSangre? tipoSangre,
    required int volumenMl,
    required String sedeId,
    required String profesionalId,
    bool? yaExisteDonacionEnCita,
    DateTime? fecha,
  }) async {
    // Valida primero aptitud y tipo de sangre antes de consultar persistencia.
    verificarEstadoAptoVigente(evaluacion);
    if (tipoSangre == null) {
      throw DonacionException(
        'El donante no tiene tipo de sangre registrado. Debe registrarse antes de continuar.',
      );
    }

    final existeDuplicado =
        yaExisteDonacionEnCita ??
        await _existeDonacionParaCita(evaluacion!.citaId);

    final resultado = prepararRegistroDonacion(
      evaluacion: evaluacion,
      tipoSangre: tipoSangre,
      yaExisteDonacionEnCita: existeDuplicado,
      volumenMl: volumenMl,
      sedeId: sedeId,
      profesionalId: profesionalId,
      fecha: fecha,
    );

    try {
      if (_persistirAtomicamente != null) {
        await _persistirAtomicamente(resultado);
      } else {
        await _guardarEnFirestoreAtomicamente(resultado);
      }
    } catch (_) {
      throw DonacionException(
        'No se pudieron guardar los datos de la donación. Se revirtieron los cambios.',
      );
    }

    return resultado;
  }

  /// Consulta en Firestore si ya existe una donación registrada para [citaId].
  Future<bool> _existeDonacionParaCita(String citaId) async {
    final consulta = await _firestore
        .collection('donaciones')
        .where('citaId', isEqualTo: citaId)
        .limit(1)
        .get();
    return consulta.docs.isNotEmpty;
  }

  /// Persiste de manera atómica la donación, la unidad de sangre y la entrada
  /// de bitácora mediante un [WriteBatch] de Firestore (escenario 7' de CU-16).
  Future<void> _guardarEnFirestoreAtomicamente(
    ResultadoRegistroDonacion resultado,
  ) async {
    final batch = _firestore.batch();

    final donacionRef = _firestore
        .collection('donaciones')
        .doc(resultado.donacion.id);
    final unidadRef = _firestore
        .collection('unidades_sangre')
        .doc(resultado.unidad.codigoBolsa);
    final bitacoraRef = _firestore.collection('bitacora').doc();

    batch.set(donacionRef, resultado.donacion.toJson());
    batch.set(unidadRef, resultado.unidad.toJson());
    batch.set(bitacoraRef, resultado.registroBitacora);

    await batch.commit();
  }
}