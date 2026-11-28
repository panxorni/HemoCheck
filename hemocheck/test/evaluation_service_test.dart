import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/cita.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/services/evaluacion_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late EvaluacionService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = EvaluacionService(firestore: fakeFirestore);
  });

  DateTime fechaNacimientoParaEdad(int edad) {
    final hoy = DateTime.now();
    return DateTime(hoy.year - edad, hoy.month, hoy.day);
  }

  group('H4 - EvaluacionService', () {
    test(
      'Sin asistencia previa: lanza EvaluacionException si la cita está en EstadoCita.activa',
          () async {
        final citaActiva = Cita(
          id: 'cita-1',
          donanteId: '12.345.678-9',
          sedeId: '123',
          bloqueId: 'bloque-1',
          fechaReserva: '2026-11-26',
          estado: EstadoCita.activa.name,
        );

        expect(
              () => service.registrarEvaluacion(
            cita: citaActiva,
            fechaNacimientoDonante: fechaNacimientoParaEdad(25),
            pesoKg: 65,
            tipoSangre: TipoSangre.oPos,
            autorizacionParental: false,
            resultado: ResultadoEvaluacion.apto,
            profesionalId: 'prof-1',
          ),
          throwsA(isA<EvaluacionException>()),
        );
      },
    );

    test(
      'Evaluación APTO exitosa: retorna Evaluacion con fechaHabilitacion == null y actualiza Firestore',
          () async {
        await fakeFirestore.collection('donantes').doc('12.345.678-9').set({
          'nombre': 'Donante Prueba',
        });

        final citaRealizada = Cita(
          id: 'cita-2',
          donanteId: '12.345.678-9',
          sedeId: '123',
          bloqueId: 'bloque-1',
          fechaReserva: '2026-11-26',
          estado: EstadoCita.realizada.name,
        );

        final evaluacion = await service.registrarEvaluacion(
          cita: citaRealizada,
          fechaNacimientoDonante: fechaNacimientoParaEdad(25),
          pesoKg: 65,
          tipoSangre: TipoSangre.oPos,
          autorizacionParental: false,
          resultado: ResultadoEvaluacion.apto,
          profesionalId: 'prof-1',
        );

        expect(evaluacion.resultado, equals(ResultadoEvaluacion.apto));
        expect(evaluacion.fechaHabilitacion, isNull);
        expect(evaluacion.donanteRut, equals('12.345.678-9'));

        // Verifica actualización en colección 'donantes'
        final donanteSnap = await fakeFirestore
            .collection('donantes')
            .doc('12.345.678-9')
            .get();
        expect(donanteSnap.data()?['pesoKg'], equals(65));
        expect(donanteSnap.data()?['tipoSangre'], equals('oPos'));

        // Verifica inserción en colección 'evaluaciones'
        final evalsSnap =
        await fakeFirestore.collection('evaluaciones').get();
        expect(evalsSnap.docs.length, equals(1));
      },
    );

    test(
      'Evaluación Diferido sin fecha: lanza EvaluacionException cuando resultado es diferidoTemporal y fechaHabilitacion es null',
          () async {
        final citaRealizada = Cita(
          id: 'cita-3',
          donanteId: '12.345.678-9',
          sedeId: '123',
          bloqueId: 'bloque-1',
          fechaReserva: '2026-11-26',
          estado: EstadoCita.realizada.name,
        );

        expect(
              () => service.registrarEvaluacion(
            cita: citaRealizada,
            fechaNacimientoDonante: fechaNacimientoParaEdad(25),
            pesoKg: 65,
            tipoSangre: TipoSangre.aNeg,
            autorizacionParental: false,
            resultado: ResultadoEvaluacion.diferidoTemporal,
            fechaHabilitacion: null,
            profesionalId: 'prof-1',
          ),
          throwsA(isA<EvaluacionException>()),
        );
      },
    );
  });
}