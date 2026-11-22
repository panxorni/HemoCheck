import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/donacion.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/models/unidad_sangre.dart';
import 'package:hemocheck/utils/donacion_validators.dart';

/// Suite de pruebas unitarias para la subtarea H5.1.
///
/// Verifica la creación de unidades de sangre con cálculo automático de
/// vencimiento a 42 días (RF-21) y las reglas de validación de volumen (RF-20).
void main() {
  group('H5.1 - Modelos de Donacion y UnidadSangre', () {
    test(
      'Cálculo de 42 días (RF-21): genera fechaVencimiento y estado disponible',
      () {
        // Arrange: donación registrada el 1 de noviembre de 2026.
        final donacion = Donacion(
          id: 'DON-001',
          citaId: 'CITA-001',
          donanteRut: '11111111-1',
          sedeId: '123',
          profesionalId: 'PROF-01',
          volumenMl: 450,
          fecha: DateTime(2026, 11, 1),
        );

        // Act: generación automática de la unidad en stock.
        final unidad = UnidadSangre.desdeDonacion(
          donacion: donacion,
          tipoSangre: TipoSangre.oPos,
        );

        // Assert: vencimiento exacto el 13 de diciembre de 2026 y estado disponible.
        expect(unidad.fechaVencimiento, DateTime(2026, 12, 13));
        expect(unidad.estado, EstadoUnidad.disponible);
        expect(unidad.donacionId, donacion.id);
        expect(unidad.sedeId, donacion.sedeId);
        expect(unidad.tipoSangre, TipoSangre.oPos);
        expect(unidad.fechaExtraccion, donacion.fecha);
      },
    );
  });

  group('H5.1 - Validador de volumen', () {
    test(
      'Retorna error con 0, negativos, sobre el máximo o valores no enteros',
      () {
        expect(DonacionValidators.validateVolumen('0'), isNotNull);
        expect(DonacionValidators.validateVolumen('-100'), isNotNull);
        expect(DonacionValidators.validateVolumen('601'), isNotNull);
        expect(DonacionValidators.validateVolumen('450.5'), isNotNull);
        expect(DonacionValidators.validateVolumen(''), isNotNull);
        expect(DonacionValidators.validateVolumen(null), isNotNull);
      },
    );

    test('Retorna null con volumen válido dentro del rango (1 a 600 ml)', () {
      expect(DonacionValidators.validateVolumen('450'), isNull);
      expect(DonacionValidators.validateVolumen('1'), isNull);
      expect(DonacionValidators.validateVolumen('600'), isNull);
    });
  });
}