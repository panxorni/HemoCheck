class Sede {
  const Sede({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.distanciaKm,
  });

  final String id;
  final String nombre;
  final String direccion;
  final double distanciaKm;

  /// Sedes de ejemplo mientras no exista un endpoint de sedes en el servidor.
  /// IMPORTANTE: la pantalla de crear bloques (BloqueHorarioScreen) guarda
  /// los bloques en la sede "123", por eso esa sede debe estar en esta lista.
  static const List<Sede> sedesDisponibles = [
    Sede(
      id: '456',
      nombre: 'Sede Norte',
      direccion: 'Av. Norte 456',
      distanciaKm: 8.4,
    ),
    Sede(
      id: '123',
      nombre: 'Sede Central',
      direccion: 'Calle Central 123',
      distanciaKm: 1.2,
    ),
    Sede(
      id: '789',
      nombre: 'Sede Sur',
      direccion: 'Av. Sur 789',
      distanciaKm: 4.7,
    ),
  ];

  /// Devuelve una copia de la lista ordenada de la sede más cercana a la más lejana.
  static List<Sede> ordenarPorDistancia(List<Sede> sedes) {
    final copia = List<Sede>.of(sedes);
    copia.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return copia;
  }
}
