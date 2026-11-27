class BloqueHorario {
  const BloqueHorario({
    required this.id,
    required this.sedeId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.capacidadMaxima,
    this.reservasActuales = 0,
    this.inscritos = const [],
    this.cerrado = false,
  });

  final String id;
  final String sedeId;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final int capacidadMaxima;
  final int reservasActuales;
  final List<String> inscritos;
  final bool cerrado;

  bool get tieneCapacidad => reservasActuales < capacidadMaxima;

  factory BloqueHorario.fromJson(Map<String, dynamic> json) {
    return BloqueHorario(
      id: json['id'] as String,
      sedeId: json['sedeId'] as String,
      fecha: json['fecha'] as String,
      horaInicio: json['horaInicio'] as String,
      horaFin: json['horaFin'] as String,
      capacidadMaxima: json['capacidadMaxima'] as int,
      reservasActuales: json['reservasActuales'] as int? ?? 0,
      inscritos: (json['inscritos'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      cerrado: json['cerrado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sedeId': sedeId,
    'fecha': fecha,
    'horaInicio': horaInicio,
    'horaFin': horaFin,
    'capacidadMaxima': capacidadMaxima,
    'reservasActuales': reservasActuales,
    'inscritos': inscritos,
    'cerrado': cerrado,
  };
}
