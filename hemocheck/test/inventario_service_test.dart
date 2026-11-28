import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/models/unidad_sangre.dart';
import 'package:hemocheck/services/inventario_service.dart';

void main() {
  late InventarioService service;

  setUp(() {
    service = const InventarioService();
  });

  group('InventarioService Tests', () {
    final fechaBase = DateTime(2026, 11, 27);

    test(
      'Acceso denegado por rol: lanza InventarioException si rolUsuario es donante',
          () {
        expect(
              () => service.agruparStockDisponible(
            rolUsuario: 'donante',
            unidades: [],
            nombresSedes: {'sede-1': 'Hospital Regional'},
            hoy: fechaBase,
          ),
          throwsA(
            isA<InventarioException>().having(
                  (e) => e.mensaje,
              'mensaje',
              'Acceso denegado: función exclusiva para Gestor de Inventario.',
            ),
          ),
        );
      },
    );

    test(
      'Descarte de vencidas y despachadas (RF-22): conteo final para O+ es 1',
          () {
        final unidades = [
          // Vigente (disponible, vence en el futuro)
          UnidadSangre(
            codigoBolsa: 'BOLSA-1',
            donacionId: 'don-1',
            sedeId: 'sede-1',
            tipoSangre: TipoSangre.oPos,
            fechaExtraccion: fechaBase.subtract(const Duration(days: 5)),
            fechaVencimiento: fechaBase.add(const Duration(days: 37)),
            estado: EstadoUnidad.disponible,
          ),
          // Vencida (marcada disponible pero con fechaVencimiento pasada)
          UnidadSangre(
            codigoBolsa: 'BOLSA-2',
            donacionId: 'don-2',
            sedeId: 'sede-1',
            tipoSangre: TipoSangre.oPos,
            fechaExtraccion: fechaBase.subtract(const Duration(days: 45)),
            fechaVencimiento: fechaBase.subtract(const Duration(days: 3)),
            estado: EstadoUnidad.disponible,
          ),
          // Despachada
          UnidadSangre(
            codigoBolsa: 'BOLSA-3',
            donacionId: 'don-3',
            sedeId: 'sede-1',
            tipoSangre: TipoSangre.oPos,
            fechaExtraccion: fechaBase.subtract(const Duration(days: 2)),
            fechaVencimiento: fechaBase.add(const Duration(days: 40)),
            estado: EstadoUnidad.despachada,
          ),
        ];

        final resultado = service.agruparStockDisponible(
          rolUsuario: 'gestor_inventario',
          unidades: unidades,
          nombresSedes: {'sede-1': 'Hospital Regional'},
          hoy: fechaBase,
        );

        expect(resultado.length, equals(1));
        expect(resultado.first.sedeId, equals('sede-1'));
        expect(resultado.first.conteoPorTipo[TipoSangre.oPos], equals(1));
        expect(resultado.first.totalDisponible, equals(1));
      },
    );

    test(
      'Agrupación por sede y tipo : retorna 2 ResumenStockSede con los conteos exactos',
          () {
        final vigenteHasta = fechaBase.add(const Duration(days: 30));
        final extraccion = fechaBase.subtract(const Duration(days: 12));

        final unidades = [
          // sede-1: 2 O+
          UnidadSangre(
            codigoBolsa: 'BOLSA-101',
            donacionId: 'don-101',
            sedeId: 'sede-1',
            tipoSangre: TipoSangre.oPos,
            fechaExtraccion: extraccion,
            fechaVencimiento: vigenteHasta,
          ),
          UnidadSangre(
            codigoBolsa: 'BOLSA-102',
            donacionId: 'don-102',
            sedeId: 'sede-1',
            tipoSangre: TipoSangre.oPos,
            fechaExtraccion: extraccion,
            fechaVencimiento: vigenteHasta,
          ),
          // sede-1: 1 A-
          UnidadSangre(
            codigoBolsa: 'BOLSA-103',
            donacionId: 'don-103',
            sedeId: 'sede-1',
            tipoSangre: TipoSangre.aNeg,
            fechaExtraccion: extraccion,
            fechaVencimiento: vigenteHasta,
          ),
          // sede-2: 1 O+
          UnidadSangre(
            codigoBolsa: 'BOLSA-201',
            donacionId: 'don-201',
            sedeId: 'sede-2',
            tipoSangre: TipoSangre.oPos,
            fechaExtraccion: extraccion,
            fechaVencimiento: vigenteHasta,
          ),
        ];

        final resultado = service.agruparStockDisponible(
          rolUsuario: 'gestor_inventario',
          unidades: unidades,
          nombresSedes: {
            'sede-1': 'Sede Concepción',
            'sede-2': 'Sede Los Ángeles',
          },
          hoy: fechaBase,
        );

        expect(resultado.length, equals(2));

        final sede1 = resultado.firstWhere((r) => r.sedeId == 'sede-1');
        expect(sede1.nombreSede, equals('Sede Concepción'));
        expect(sede1.conteoPorTipo[TipoSangre.oPos], equals(2));
        expect(sede1.conteoPorTipo[TipoSangre.aNeg], equals(1));
        expect(sede1.totalDisponible, equals(3));

        final sede2 = resultado.firstWhere((r) => r.sedeId == 'sede-2');
        expect(sede2.nombreSede, equals('Sede Los Ángeles'));
        expect(sede2.conteoPorTipo[TipoSangre.oPos], equals(1));
        expect(sede2.totalDisponible, equals(1));
      },
    );
  });
}