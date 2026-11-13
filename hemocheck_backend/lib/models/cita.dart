/// Cita de un donante en un bloque horario (HU3).
class Cita {
  const Cita({
    required this.id,
    required this.donanteId,
    required this.sedeId,
    required this.bloqueId,
    required this.fechaReserva,
    this.estado = estadoActiva,
  });

  static const String estadoActiva = 'activa';

  final String id;
  final String donanteId;
  final String sedeId;
  final String bloqueId;
  final String fechaReserva;
  final String estado;

  bool get estaActiva => estado == estadoActiva;

  Map<String, dynamic> toJson() => {
    'id': id,
    'donanteId': donanteId,
    'sedeId': sedeId,
    'bloqueId': bloqueId,
    'fechaReserva': fechaReserva,
    'estado': estado,
  };
}