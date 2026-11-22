/// Representa el registro clínico de una extracción de sangre realizada a un donante.
///
/// Modela los datos requeridos por RF-20 y CU-16 (identificación del donante,
/// volumen extraído, fecha y sede), además de la referencia a la cita evaluada
/// y al profesional responsable 
class Donacion {
  /// Crea una instancia inmutable de [Donacion].
  const Donacion({
    required this.id,
    required this.citaId,
    required this.donanteRut,
    required this.sedeId,
    required this.profesionalId,
    required this.volumenMl,
    required this.fecha,
  });

  /// Identificador único de la donación registrada.
  final String id;

  /// Identificador de la cita atendida cuya evaluación habilitó esta donación.
  final String citaId;

  /// RUT normalizado del donante al que se le realizó la extracción.
  final String donanteRut;

  /// Identificador de la sede del banco de sangre donde ocurrió la extracción.
  final String sedeId;

  /// Identificador del profesional de salud que registró la donación.
  final String profesionalId;

  /// Volumen de sangre extraído, expresado en mililitros (ml).
  final int volumenMl;

  /// Fecha y hora en que se efectuó la extracción.
  final DateTime fecha;

  /// Crea una instancia de [Donacion] a partir de un mapa decodificado desde JSON.
  ///
  /// Espera que el campo `fecha` esté serializado en formato ISO-8601.
  factory Donacion.fromJson(Map<String, dynamic> json) {
    return Donacion(
      id: json['id'] as String,
      citaId: json['citaId'] as String,
      donanteRut: json['donanteRut'] as String,
      sedeId: json['sedeId'] as String,
      profesionalId: json['profesionalId'] as String,
      volumenMl: json['volumenMl'] as int,
      fecha: DateTime.parse(json['fecha'] as String),
    );
  }

  /// Convierte esta instancia de [Donacion] en un mapa compatible con JSON.
  ///
  /// Serializa [fecha] en formato estándar ISO-8601.
  Map<String, dynamic> toJson() => {
    'id': id,
    'citaId': citaId,
    'donanteRut': donanteRut,
    'sedeId': sedeId,
    'profesionalId': profesionalId,
    'volumenMl': volumenMl,
    'fecha': fecha.toIso8601String(),
  };
}