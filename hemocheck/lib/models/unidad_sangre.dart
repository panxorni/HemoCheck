import 'package:hemocheck/models/donacion.dart';
import 'package:hemocheck/models/evaluacion.dart';

/// Estados posibles del ciclo de vida de una unidad de sangre en el inventario.
///
/// Toda unidad ingresa como [disponible] y deja de estarlo al pasar a
/// [despachada] (RF-26) o [vencida] (RF-22).
enum EstadoUnidad {
  /// Unidad vigente y habilitada para ser despachada a un hospital.
  disponible,

  /// Unidad ya asignada y enviada a un centro hospitalario.
  despachada,

  /// Unidad cuya fecha de vencimiento fue superada; no apta para uso.
  vencida,
}

/// Representa una bolsa o unidad de sangre almacenada en el stock de una sede.
///
/// Se genera automáticamente a partir de una [Donacion] con una vigencia
/// estándar de 42 días desde la fecha de extracción (RF-21, CU-18).
class UnidadSangre {
  /// Crea una instancia inmutable de [UnidadSangre].
  ///
  /// Por defecto, [estado] se inicializa en [EstadoUnidad.disponible].
  const UnidadSangre({
    required this.codigoBolsa,
    required this.donacionId,
    required this.sedeId,
    required this.tipoSangre,
    required this.fechaExtraccion,
    required this.fechaVencimiento,
    this.estado = EstadoUnidad.disponible,
  });

  /// Vigencia estándar en días para la conservación de glóbulos rojos (RF-21).
  static const int diasVigencia = 42;

  /// Código identificador único de la bolsa de sangre en inventario.
  final String codigoBolsa;

  /// Identificador de la [Donacion] que originó esta unidad.
  final String donacionId;

  /// Identificador de la sede donde se encuentra almacenada la unidad.
  final String sedeId;

  /// Grupo sanguíneo y factor Rh correspondiente a la unidad.
  final TipoSangre tipoSangre;

  /// Fecha y hora en que se realizó la extracción de sangre.
  final DateTime fechaExtraccion;

  /// Fecha límite de vigencia de la unidad ([fechaExtraccion] + 42 días).
  final DateTime fechaVencimiento;

  /// Estado actual de disponibilidad de la unidad en el inventario.
  final EstadoUnidad estado;

  /// Genera una nueva [UnidadSangre] a partir de una [donacion] registrada.
  ///
  /// Calcula automáticamente [fechaVencimiento] sumando [diasVigencia] (42 días)
  /// a [Donacion.fecha] y asigna el estado inicial [EstadoUnidad.disponible]
  /// según lo especificado en RF-21 y CU-18.
  factory UnidadSangre.desdeDonacion({
    required Donacion donacion,
    required TipoSangre tipoSangre,
  }) {
    final fechaVencimiento = donacion.fecha.add(
      const Duration(days: diasVigencia),
    );
    return UnidadSangre(
      codigoBolsa: 'BOLSA-${donacion.fecha.millisecondsSinceEpoch}',
      donacionId: donacion.id,
      sedeId: donacion.sedeId,
      tipoSangre: tipoSangre,
      fechaExtraccion: donacion.fecha,
      fechaVencimiento: fechaVencimiento,
      estado: EstadoUnidad.disponible,
    );
  }

  /// Crea una instancia de [UnidadSangre] a partir de un mapa decodificado desde JSON.
  ///
  /// Espera fechas en formato ISO-8601 y los nombres literales de [TipoSangre]
  /// y [EstadoUnidad].
  factory UnidadSangre.fromJson(Map<String, dynamic> json) {
    return UnidadSangre(
      codigoBolsa: json['codigoBolsa'] as String,
      donacionId: json['donacionId'] as String,
      sedeId: json['sedeId'] as String,
      tipoSangre: TipoSangre.values.byName(json['tipoSangre'] as String),
      fechaExtraccion: DateTime.parse(json['fechaExtraccion'] as String),
      fechaVencimiento: DateTime.parse(json['fechaVencimiento'] as String),
      estado: EstadoUnidad.values.byName(json['estado'] as String),
    );
  }

  /// Convierte esta instancia de [UnidadSangre] en un mapa compatible con JSON.
  ///
  /// Serializa las fechas en formato ISO-8601 y las enumeraciones mediante `.name`.
  Map<String, dynamic> toJson() => {
    'codigoBolsa': codigoBolsa,
    'donacionId': donacionId,
    'sedeId': sedeId,
    'tipoSangre': tipoSangre.name,
    'fechaExtraccion': fechaExtraccion.toIso8601String(),
    'fechaVencimiento': fechaVencimiento.toIso8601String(),
    'estado': estado.name,
  };
}