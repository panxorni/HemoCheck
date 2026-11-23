import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/models/resumen_inventario.dart';
import 'package:hemocheck/models/unidad_sangre.dart';

UnidadSangre _unidad({EstadoUnidad estado = EstadoUnidad.disponible}) {
  return UnidadSangre(
    codigoBolsa: 'BOLSA-1',
    donacionId: 'DON-1',
    sedeId: 'sede-1',
    tipoSangre: TipoSangre.oPos,
    fechaExtraccion: DateTime(2026, 9, 29),
    fechaVencimiento: DateTime(2026, 11, 10),
    estado: estado,
  );
}

void main() {
  group('H6.1 - Caducidad de UnidadSangre', () {
    test('Unidad vencida (RF-22): estaVencida true y estaDisponible false', () {
      final unidad = _unidad();
      final hoy = DateTime(2026, 11, 11);

      expect(unidad.estaVencida(hoy: hoy), isTrue);
      expect(unidad.estaDisponible(hoy: hoy), isFalse);
    });

    test('Unidad vigente: estaVencida false y estaDisponible true', () {
      final unidad = _unidad();
      final hoy = DateTime(2026, 11, 10);

      expect(unidad.estaVencida(hoy: hoy), isFalse);
      expect(unidad.estaDisponible(hoy: hoy), isTrue);
    });

    test('copiarConEstado devuelve otra instancia y no muta la original', () {
      final original = _unidad();
      final vencida = original.copiarConEstado(EstadoUnidad.vencida);

      expect(vencida.estado, EstadoUnidad.vencida);
      expect(original.estado, EstadoUnidad.disponible);
      expect(vencida.codigoBolsa, original.codigoBolsa);
    });

    test('Una unidad despachada no está disponible aunque no haya vencido', () {
      final unidad = _unidad(estado: EstadoUnidad.despachada);

      expect(unidad.estaDisponible(hoy: DateTime(2026, 11, 1)), isFalse);
    });
  });

  group('H6.1 - ResumenStockSede', () {
    test('totalDisponible suma los conteos de todos los tipos', () {
      const resumen = ResumenStockSede(
        sedeId: 'sede-1',
        nombreSede: 'Sede Centro',
        conteoPorTipo: {TipoSangre.oPos: 2, TipoSangre.aNeg: 1},
      );

      expect(resumen.totalDisponible, 3);
    });
  });
}