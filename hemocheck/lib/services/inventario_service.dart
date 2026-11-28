import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/models/resumen_inventario.dart';
import 'package:hemocheck/models/unidad_sangre.dart';

class InventarioException implements Exception {
  final String mensaje;
  InventarioException(this.mensaje);

  @override
  String toString() => mensaje;
}

class InventarioService {
  const InventarioService();

  /// Valida que el usuario tenga el rol de 'gestor_inventario'
  void validarRolGestor(String rolUsuario) {
    if (rolUsuario != 'gestor_inventario') {
      throw InventarioException(
        'Acceso denegado: función exclusiva para Gestor de Inventario.',
      );
    }
  }

  /// Recorre las unidades en estado disponible y marca como [EstadoUnidad.vencida]
  /// todas aquellas cuya fecha de vencimiento fue superada según [hoy]
  List<UnidadSangre> actualizarVencidas(
      List<UnidadSangre> unidades, {
        DateTime? hoy,
      }) {
    final actualizadas = <UnidadSangre>[];

    for (var i = 0; i < unidades.length; i++) {
      final unidad = unidades[i];
      if (unidad.estado == EstadoUnidad.disponible &&
          unidad.estaVencida(hoy: hoy)) {
        final vencida = unidad.copiarConEstado(EstadoUnidad.vencida);
        actualizadas.add(vencida);
        // Si la lista recibida no es de longitud fija/inmutable, también la actualiza en sitio
        try {
          unidades[i] = vencida;
        } on UnsupportedError {
          // Ignora si se pasó una lista const o no modificable
        }
      } else {
        actualizadas.add(unidad);
      }
    }

    return actualizadas;
  }

  /// Valida rol, actualiza vencidas, filtra disponibles y agrupa el stock
  /// por sede y tipo de sangre
  List<ResumenStockSede> agruparStockDisponible({
    required String rolUsuario,
    required List<UnidadSangre> unidades,
    required Map<String, String> nombresSedes,
    DateTime? hoy,
  }) {
    // Validar rol
    validarRolGestor(rolUsuario);

    // Actualizar unidades vencidas
    final unidadesActualizadas = actualizarVencidas(unidades, hoy: hoy);

    // Filtrar únicamente las disponibles (descarta vencidas y despachadas)
    final disponibles = unidadesActualizadas
        .where((u) => u.estado == EstadoUnidad.disponible)
        .toList();

    // Agrupar por sedeId y contar por TipoSangre
    final Map<String, Map<TipoSangre, int>> agrupado = {};

    for (final unidad in disponibles) {
      final mapaTipos = agrupado.putIfAbsent(unidad.sedeId, () => {});
      mapaTipos[unidad.tipoSangre] = (mapaTipos[unidad.tipoSangre] ?? 0) + 1;
    }

    return agrupado.entries.map((entry) {
      final sedeId = entry.key;
      return ResumenStockSede(
        sedeId: sedeId,
        nombreSede: nombresSedes[sedeId] ?? sedeId,
        conteoPorTipo: entry.value,
      );
    }).toList();
  }
}