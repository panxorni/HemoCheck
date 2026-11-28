import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/models/unidad_sangre.dart';
import 'package:hemocheck/services/donacion_service.dart';

/// Suite de pruebas unitarias para la subtarea H5.2.
///
/// Cubre la verificación obligatoria de estado apto vigente (RF-19, CU-17),
/// validaciones previas y de duplicidad (CU-16), generación de unidad a +42 días
/// (RF-21, CU-18), registro de bitácora (RNF-07) y reversión ante fallo atómico.
void main() {
  late DonacionService service;

  /// Crea una evaluación de prueba con el [resultado] especificado.
  Evaluacion crearEvaluacion(
    ResultadoEvaluacion resultado, {
    DateTime? fechaHabilitacion,
  }) {
    return Evaluacion(
      citaId: 'CITA-001',
      donanteRut: '11111111-1',
      profesionalId: 'PROF-01',
      fecha: DateTime(2026, 11, 1),
      resultado: resultado,
      fechaHabilitacion: fechaHabilitacion,
    );
  }

  setUp(() {
    // Inyecta persistencia simulada sin requerir conexión real a Firebase.
    service = DonacionService(persistirAtomicamente: (_) async {});
  });

  group('H5.2 - Verificación de aptitud y bloqueos (CU-17 / CU-16)', () {
    test(
      'Bloqueo por no apto (RF-19): lanza DonacionException con null, diferidoTemporal y rechazadoPermanente',
      () async {
        final diferido = crearEvaluacion(
          ResultadoEvaluacion.diferidoTemporal,
          fechaHabilitacion: DateTime(2027, 2, 1),
        );
        final rechazado = crearEvaluacion(
          ResultadoEvaluacion.rechazadoPermanente,
        );

        // Verificación directa en CU-17.
        expect(
          () => service.verificarEstadoAptoVigente(null),
          throwsA(isA<DonacionException>()),
        );
        expect(
          () => service.verificarEstadoAptoVigente(diferido),
          throwsA(isA<DonacionException>()),
        );
        expect(
          () => service.verificarEstadoAptoVigente(rechazado),
          throwsA(isA<DonacionException>()),
        );

        // Verificación integrada en registrarDonacion.
        await expectLater(
          service.registrarDonacion(
            evaluacion: null,
            tipoSangre: TipoSangre.oPos,
            yaExisteDonacionEnCita: false,
            volumenMl: 450,
            sedeId: '123',
            profesionalId: 'PROF-01',
          ),
          throwsA(isA<DonacionException>()),
        );
        await expectLater(
          service.registrarDonacion(
            evaluacion: diferido,
            tipoSangre: TipoSangre.oPos,
            yaExisteDonacionEnCita: false,
            volumenMl: 450,
            sedeId: '123',
            profesionalId: 'PROF-01',
          ),
          throwsA(isA<DonacionException>()),
        );
        await expectLater(
          service.registrarDonacion(
            evaluacion: rechazado,
            tipoSangre: TipoSangre.oPos,
            yaExisteDonacionEnCita: false,
            volumenMl: 450,
            sedeId: '123',
            profesionalId: 'PROF-01',
          ),
          throwsA(isA<DonacionException>()),
        );
      },
    );

    test(
      'Bloqueo sin tipo de sangre (escenario 3\'): lanza DonacionException si tipoSangre es null',
      () async {
        final apto = crearEvaluacion(ResultadoEvaluacion.apto);

        await expectLater(
          service.registrarDonacion(
            evaluacion: apto,
            tipoSangre: null,
            yaExisteDonacionEnCita: false,
            volumenMl: 450,
            sedeId: '123',
            profesionalId: 'PROF-01',
          ),
          throwsA(isA<DonacionException>()),
        );
      },
    );

    test(
      'Bloqueo de duplicado (escenario 5\'): lanza DonacionException si yaExisteDonacionEnCita es true',
      () async {
        final apto = crearEvaluacion(ResultadoEvaluacion.apto);

        await expectLater(
          service.registrarDonacion(
            evaluacion: apto,
            tipoSangre: TipoSangre.oPos,
            yaExisteDonacionEnCita: true,
            volumenMl: 450,
            sedeId: '123',
            profesionalId: 'PROF-01',
          ),
          throwsA(isA<DonacionException>()),
        );
      },
    );

    test(
      'Bloqueo por volumen inválido (escenario 4\'): lanza DonacionException si volumenMl <= 0',
      () async {
        final apto = crearEvaluacion(ResultadoEvaluacion.apto);

        await expectLater(
          service.registrarDonacion(
            evaluacion: apto,
            tipoSangre: TipoSangre.oPos,
            yaExisteDonacionEnCita: false,
            volumenMl: 0,
            sedeId: '123',
            profesionalId: 'PROF-01',
          ),
          throwsA(isA<DonacionException>()),
        );
      },
    );
  });

  group('H5.2 - Registro exitoso y atomicidad (RF-20, RF-21, RNF-07)', () {
    test(
      'Registro exitoso completo: retorna donacion, unidad (+42 días) y bitacora con usuarioId y fechaHora',
      () async {
        // Arrange
        final apto = crearEvaluacion(ResultadoEvaluacion.apto);
        final fechaExtraccion = DateTime(2026, 11, 1, 10, 30);

        // Act
        final resultado = await service.registrarDonacion(
          evaluacion: apto,
          tipoSangre: TipoSangre.oPos,
          yaExisteDonacionEnCita: false,
          volumenMl: 450,
          sedeId: '123',
          profesionalId: 'PROF-01',
          fecha: fechaExtraccion,
        );

        // Assert: datos de Donacion (RF-20)
        expect(resultado.donacion.citaId, 'CITA-001');
        expect(resultado.donacion.donanteRut, '11111111-1');
        expect(resultado.donacion.sedeId, '123');
        expect(resultado.donacion.profesionalId, 'PROF-01');
        expect(resultado.donacion.volumenMl, 450);
        expect(resultado.donacion.fecha, fechaExtraccion);

        // Assert: datos de UnidadSangre con vencimiento a +42 días (RF-21)
        expect(
          resultado.unidad.fechaVencimiento,
          fechaExtraccion.add(const Duration(days: 42)),
        );
        expect(resultado.unidad.estado, EstadoUnidad.disponible);
        expect(resultado.unidad.tipoSangre, TipoSangre.oPos);
        expect(resultado.unidad.donacionId, resultado.donacion.id);

        // Assert: trazabilidad en bitácora (RNF-07)
        expect(resultado.registroBitacora['usuarioId'], 'PROF-01');
        expect(resultado.registroBitacora['accion'], 'REGISTRAR_DONACION');
        expect(
          resultado.registroBitacora['codigoBolsa'],
          resultado.unidad.codigoBolsa,
        );
        expect(
          resultado.registroBitacora['fechaHora'],
          fechaExtraccion.toIso8601String(),
        );
      },
    );

    test(
      'Fallo en persistencia atómica (escenario 7\'): lanza DonacionException si falla el guardado',
      () async {
        final serviceConFallo = DonacionService(
          persistirAtomicamente: (_) async {
            throw Exception('Fallo simulado de red en WriteBatch');
          },
        );
        final apto = crearEvaluacion(ResultadoEvaluacion.apto);

        await expectLater(
          serviceConFallo.registrarDonacion(
            evaluacion: apto,
            tipoSangre: TipoSangre.oPos,
            yaExisteDonacionEnCita: false,
            volumenMl: 450,
            sedeId: '123',
            profesionalId: 'PROF-01',
          ),
          throwsA(isA<DonacionException>()),
        );
      },
    );
  });
}