enum TipoSangre { aPos, aNeg, bPos, bNeg, abPos, abNeg, oPos, oNeg }

enum ResultadoEvaluacion { apto, diferidoTemporal, rechazadoPermanente }

// Resultado de una evaluacion clinica de un donante en una cita
class Evaluacion {
    const Evaluacion({
        required this.citaId,
        required this.donanteRut,
        required this.profesionalId,
        required this.fecha,
        required this.resultado,
        this.fechaHabilitacion,
    });

     
    final String citaId;
    final String donanteRut;
    final String profesionalId;
    final DateTime fecha;
    final ResultadoEvaluacion resultado;

    final DateTime? fechaHabilitacion;

    /// Crea una instancia de [Evaluacion] a partir de un mapa decodificado desde JSON
    factory Evaluacion.fromJson(Map<String, dynamic> json) {
        return Evaluacion(
            citaId: json['citaId'] as String, 
            donanteRut: json['donanteRut'] as String, 
            profesionalId: json['profesionalId'] as String, 
            fecha: DateTime.parse(json['fecha'] as String), 
            resultado: ResultadoEvaluacion.values.byName(json['resultado'] as String), 
            fechaHabilitacion: json['fechaHabilitacion'] == null 
                ? null 
                : DateTime.parse(json['fechaHabilitacion'] as String),
            );
    }

    /// Convierte la instancia de [Evaluacion] a un mapa compatible con JSON
    Map<String, dynamic> toJson() => {
        'citaId': citaId,
        'donanteRut': donanteRut,
        'profesionalId': profesionalId,

        //// Serializa las fechas en formato estándar ISO 8601 (fecha: [AAAA-MM-DD], hora(24 hrs): [hh:mm:ss])
        'fecha': fecha.toIso8601String(),
        'resultado': resultado.name,
        'fechaHabilitacion': fechaHabilitacion?.toIso8601String(),
    };
}