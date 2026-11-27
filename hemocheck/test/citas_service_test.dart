import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/services/citas_service.dart';

const _donante1 = 'donante1@correo.cl';
const _donante2 = 'donante2@correo.cl';

String _fechaFutura() {
  final f = DateTime.now().add(const Duration(days: 30));
  final mes = f.month.toString().padLeft(2, '0');
  final dia = f.day.toString().padLeft(2, '0');
  return '${f.year}-$mes-$dia';
}

/// Base simulada con dos bloques en la sede 123 y dos donantes registrados.
Future<FakeFirebaseFirestore> _baseDeDatos({
  int capacidad = 5,
  int reservas = 0,
  bool cerrado = false,
}) async {
  final db = FakeFirebaseFirestore();
  for (final id in ['bloque-1', 'bloque-2']) {
    await db.collection('sedes').doc('123').collection('horarios').doc(id).set({
      'sedeId': '123',
      'fecha': _fechaFutura(),
      'horaInicio': '09:00',
      'horaFin': '10:00',
      'capacidadMaxima': capacidad,
      'reservasActuales': reservas,
      'inscritos': <String>[],
      'cerrado': cerrado,
    });
  }
  await db
      .collection('usuarios')
      .doc('uid-1')
      .set({'rut': '12345678-5', 'rol': 'donante'});
  await db
      .collection('usuarios')
      .doc('uid-2')
      .set({'rut': '11111111-1', 'rol': 'donante'});
  return db;
}

Future<ReservaConfirmada> _reservar(
  CitasService service, {
  String uid = 'uid-1',
  String identificador = _donante1,
  String bloque = 'bloque-1',
}) {
  return service.reservar(
    donanteId: uid,
    identificador: identificador,
    sedeId: '123',
    bloqueId: bloque,
  );
}

Future<void> _cancelar(
  CitasService service, {
  String uid = 'uid-1',
  String identificador = _donante1,
  String bloque = 'bloque-1',
}) {
  return service.cancelar(
    donanteId: uid,
    identificador: identificador,
    sedeId: '123',
    bloqueId: bloque,
  );
}

Future<Map<String, dynamic>> _datosBloque(
    FakeFirebaseFirestore db, String id) async {
  final doc =
      await db.collection('sedes').doc('123').collection('horarios').doc(id).get();
  return doc.data()!;
}

Future<int> _cantidadCitas(FakeFirebaseFirestore db) async {
  return (await db.collection('citas').get()).docs.length;
}

Matcher _errorCon(String mensaje) => throwsA(
      isA<CitaException>().having((e) => e.mensaje, 'mensaje', mensaje),
    );

void main() {
  group('Reserva de bloque horario (HU3)', () {
    test('Reserva exitosa: crea la cita activa y descuenta un cupo', () async {
      final db = await _baseDeDatos(capacidad: 5);
      final service = CitasService(db: db);

      final reserva = await _reservar(service);

      expect(reserva.codigoReserva, startsWith('HC-'));
      expect(reserva.horaInicio, '09:00');
      expect(reserva.horaFin, '10:00');

      final citas = await db.collection('citas').get();
      expect(citas.docs.length, 1);
      final cita = citas.docs.first.data();
      expect(cita['estado'], 'activa');
      expect(cita['uid'], 'uid-1');
      expect(cita['bloqueId'], 'bloque-1');
      expect(cita['codigoReserva'], reserva.codigoReserva);

      final bloque = await _datosBloque(db, 'bloque-1');
      expect(bloque['reservasActuales'], 1);
      expect(bloque['inscritos'], [_donante1]);

      final usuario = await db.collection('usuarios').doc('uid-1').get();
      expect(usuario.data()!['citaActivaId'], citas.docs.first.id);
    });

    test('Bloque sin cupo: rechaza la reserva y no crea la cita', () async {
      final db = await _baseDeDatos(capacidad: 3, reservas: 3);
      final service = CitasService(db: db);

      await expectLater(
        _reservar(service),
        _errorCon('El bloque seleccionado no tiene cupos disponibles.'),
      );

      expect(await _cantidadCitas(db), 0);
      expect((await _datosBloque(db, 'bloque-1'))['reservasActuales'], 3);
    });

    test('Cita activa existente: rechaza una segunda cita activa', () async {
      final db = await _baseDeDatos();
      final service = CitasService(db: db);

      await _reservar(service, bloque: 'bloque-1');

      await expectLater(
        _reservar(service, bloque: 'bloque-2'),
        _errorCon('Ya tienes una cita activa. No puedes reservar otra.'),
      );

      expect(await _cantidadCitas(db), 1);
      expect((await _datosBloque(db, 'bloque-2'))['reservasActuales'], 0);
    });

    test('Último cupo: solo el primer donante lo obtiene', () async {
      final db = await _baseDeDatos(capacidad: 1);
      final service = CitasService(db: db);

      await _reservar(service);

      await expectLater(
        _reservar(service, uid: 'uid-2', identificador: _donante2),
        _errorCon('El bloque seleccionado no tiene cupos disponibles.'),
      );

      expect(await _cantidadCitas(db), 1);
      expect((await _datosBloque(db, 'bloque-1'))['reservasActuales'], 1);
    });

    test('Bloque cerrado: rechaza la reserva', () async {
      final db = await _baseDeDatos(cerrado: true);
      final service = CitasService(db: db);

      await expectLater(
        _reservar(service),
        _errorCon('Este bloque horario fue cerrado por la sede.'),
      );
      expect(await _cantidadCitas(db), 0);
    });

    test('Bloque inexistente: rechaza la reserva', () async {
      final db = await _baseDeDatos();
      final service = CitasService(db: db);

      await expectLater(
        _reservar(service, bloque: 'no-existe'),
        _errorCon('El bloque horario seleccionado no existe.'),
      );
      expect(await _cantidadCitas(db), 0);
    });

    test('Si la sede saca al donante del bloque, puede reservar otro',
        () async {
      final db = await _baseDeDatos();
      final service = CitasService(db: db);

      await _reservar(service, bloque: 'bloque-1');
      // La sede lo saca de la lista de inscritos del bloque 1
      await db
          .collection('sedes')
          .doc('123')
          .collection('horarios')
          .doc('bloque-1')
          .update({'inscritos': <String>[], 'reservasActuales': 0});

      final reserva = await _reservar(service, bloque: 'bloque-2');

      expect(reserva.bloqueId, 'bloque-2');
    });
  });

  group('Cancelación de reserva (HU3)', () {
    test('Cancelar libera el cupo, marca la cita y permite reservar de nuevo',
        () async {
      final db = await _baseDeDatos();
      final service = CitasService(db: db);

      await _reservar(service, bloque: 'bloque-1');
      await _cancelar(service, bloque: 'bloque-1');

      final bloque = await _datosBloque(db, 'bloque-1');
      expect(bloque['reservasActuales'], 0);
      expect(bloque['inscritos'], isEmpty);

      final citas = await db.collection('citas').get();
      expect(citas.docs.first.data()['estado'], 'cancelada');

      final usuario = await db.collection('usuarios').doc('uid-1').get();
      expect(usuario.data()!['citaActivaId'], isNull);

      final nueva = await _reservar(service, bloque: 'bloque-2');
      expect(nueva.bloqueId, 'bloque-2');
    });

    test('Cancelar sin tener reserva en el bloque devuelve un error',
        () async {
      final db = await _baseDeDatos();
      final service = CitasService(db: db);

      await expectLater(
        _cancelar(service),
        _errorCon('No tienes una reserva activa en este bloque.'),
      );
    });

    test('Cancelar en un bloque cerrado devuelve un error', () async {
      final db = await _baseDeDatos();
      final service = CitasService(db: db);

      await _reservar(service);
      await db
          .collection('sedes')
          .doc('123')
          .collection('horarios')
          .doc('bloque-1')
          .update({'cerrado': true});

      await expectLater(
        _cancelar(service),
        _errorCon('Este bloque horario fue cerrado por la sede.'),
      );
    });
  });
}
