class BloqueHorario {
  const BloqueHorario({
    required this.id,
    required this.sedeId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.capacidadMaxima,
    this.reservasActuales = 0,
  });

  final String id;
  final String sedeId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final int capacidadMaxima;
  final int reservasActuales;

  bool get tieneCapacidad => reservasActuales < capacidadMaxima;

  factory BloqueHorario.fromJson(Map<String, dynamic> json) {
    return BloqueHorario(
      id: json['id'] as String,
      sedeId: json['sedeId'] as String,
      diaSemana: json['diaSemana'] as int,
      horaInicio: json['horaInicio'] as String,
      horaFin: json['horaFin'] as String,
      capacidadMaxima: json['capacidadMaxima'] as int,
      reservasActuales: json['reservasActuales'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sedeId': sedeId,
    'diaSemana': diaSemana,
    'horaInicio': horaInicio,
    'horaFin': horaFin,
    'capacidadMaxima': capacidadMaxima,
    'reservasActuales': reservasActuales,
  };
}
//Nota: hay una carpeta llamada route con las sedes y una sede simulada llamada 123 que seria el id de esa sede