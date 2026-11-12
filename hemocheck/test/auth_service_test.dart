import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/services/auth_service.dart';

/// Auth simulado que puede fallar al registrar o al iniciar sesión.
class _AuthQueFalla extends MockFirebaseAuth {
  final String? codigoRegistro;
  final String? codigoLogin;

  _AuthQueFalla({this.codigoRegistro, this.codigoLogin});

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (codigoRegistro != null) {
      throw FirebaseAuthException(code: codigoRegistro!);
    }
    return super
        .createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (codigoLogin != null) {
      throw FirebaseAuthException(code: codigoLogin!);
    }
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

DateTime _nacimientoValido() {
  final h = DateTime.now();
  return DateTime(h.year - 25, h.month, h.day);
}

Future<void> _registrar(
  AuthService s, {
  String rut = '12345678-5',
  String correo = 'ana.torres@correo.cl',
  DateTime? fecha,
}) {
  return s.registrar(
    rut: rut,
    nombre: 'Ana Torres',
    fechaNacimiento: fecha ?? _nacimientoValido(),
    telefono: '+56911111111',
    correo: correo,
    contrasena: 'Hemo1234',
  );
}

Matcher _errorCon(String mensaje) => throwsA(
      isA<AuthException>().having((e) => e.mensaje, 'mensaje', mensaje),
    );

void main() {
  group('Registro', () {
    test('Registro exitoso: crea la cuenta, el usuario y el donante', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, db: db);

      await _registrar(service);

      final donante = await db.collection('donantes').doc('12345678-5').get();
      expect(donante.exists, isTrue);

      final usuarios = await db.collection('usuarios').get();
      expect(usuarios.docs.length, 1);
      final datos = usuarios.docs.first.data();
      expect(datos['rut'], '12345678-5');
      expect(datos['nombre'], 'Ana Torres');
      expect(datos['correo'], 'ana.torres@correo.cl');
      expect(datos['rol'], 'donante');
      expect(auth.currentUser, isNotNull);
    });

    test('RUT duplicado: rechaza el registro y no guarda un usuario nuevo',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('donantes').doc('12345678-5').set({'uid': 'otro'});
      final service = AuthService(auth: MockFirebaseAuth(), db: db);

      await expectLater(
        _registrar(service, rut: '12.345.678-5', correo: 'otra@correo.cl'),
        _errorCon('Ya existe una cuenta con este RUT.'),
      );

      final usuarios = await db.collection('usuarios').get();
      expect(usuarios.docs, isEmpty);
    });

    test('Correo duplicado: rechaza el registro', () async {
      final db = FakeFirebaseFirestore();
      final auth = _AuthQueFalla(codigoRegistro: 'email-already-in-use');
      final service = AuthService(auth: auth, db: db);

      await expectLater(
        _registrar(service),
        _errorCon('Ya existe una cuenta con este correo.'),
      );

      final usuarios = await db.collection('usuarios').get();
      expect(usuarios.docs, isEmpty);
    });

    test('Fecha de nacimiento de hoy: rechaza el registro por edad', () async {
      final db = FakeFirebaseFirestore();
      final service = AuthService(auth: MockFirebaseAuth(), db: db);

      await expectLater(
        _registrar(service, fecha: DateTime.now()),
        _errorCon(
            'La fecha de nacimiento está fuera del rango permitido (17 a 70 años).'),
      );
      expect((await db.collection('usuarios').get()).docs, isEmpty);
    });

    test('Mayor de 70 años: rechaza el registro por edad', () async {
      final h = DateTime.now();
      final service =
          AuthService(auth: MockFirebaseAuth(), db: FakeFirebaseFirestore());

      await expectLater(
        _registrar(service, fecha: DateTime(h.year - 80, h.month, h.day)),
        _errorCon(
            'La fecha de nacimiento está fuera del rango permitido (17 a 70 años).'),
      );
    });

    test('El RUT se normaliza sin puntos y con guion', () {
      final service =
          AuthService(auth: MockFirebaseAuth(), db: FakeFirebaseFirestore());
      expect(service.normalizarRut('12.345.678-5'), '12345678-5');
      expect(service.normalizarRut('123456785'), '12345678-5');
      expect(service.normalizarRut('23.000.000-k'), '23000000-K');
    });
  });

  group('Inicio de sesión', () {
    test('Login exitoso: deja un usuario autenticado', () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, db: FakeFirebaseFirestore());

      await service.iniciarSesion('ana.torres@correo.cl', 'Hemo1234');

      expect(auth.currentUser, isNotNull);
    });

    test('Login fallido: credenciales incorrectas devuelven un error',
        () async {
      final auth = _AuthQueFalla(codigoLogin: 'invalid-credential');
      final service = AuthService(auth: auth, db: FakeFirebaseFirestore());

      await expectLater(
        service.iniciarSesion('ana.torres@correo.cl', 'Hemo9999'),
        _errorCon('Correo o contraseña incorrectos.'),
      );
      expect(auth.currentUser, isNull);
    });

    test('Cerrar sesión: deja de haber usuario autenticado', () async {
      final auth = MockFirebaseAuth(signedIn: true);
      final service = AuthService(auth: auth, db: FakeFirebaseFirestore());

      await service.cerrarSesion();

      expect(auth.currentUser, isNull);
    });
  });
}