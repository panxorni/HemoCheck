import 'package:hemocheck/models/evaluacion.dart';

/// Resumen del stock disponible de una sede, agrupado por tipo de sangre (RF-23).
class ResumenStockSede {
  /// Crea un resumen inmutable del stock de una sede.
  const ResumenStockSede({
    required this.sedeId,
    required this.nombreSede,
    required this.conteoPorTipo,
  });

  /// Identificador de la sede.
  final String sedeId;

  /// Nombre de la sede para mostrar en pantalla.
  final String nombreSede;

  /// Cantidad de unidades disponibles por cada [TipoSangre].
  final Map<TipoSangre, int> conteoPorTipo;

  /// Total de unidades disponibles en la sede, sumando todos los tipos.
  int get totalDisponible =>
      conteoPorTipo.values.fold(0, (suma, cantidad) => suma + cantidad);
}