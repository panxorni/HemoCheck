import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthException implements Exception {
  final String mensaje;
  AuthException(this.mensaje);
  @override
  String toString() => mensaje;
}

class AuthService {
  static const int edadMinima = 17;
  static const int edadMaxima = 70;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  // Sin argumentos usa Firebase real; los tests pasan versiones simuladas.
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  // 12.345.678-5 y 123456785 quedan ambos como 12345678-5
  String normalizarRut(String rut) {
    final limpio = rut.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    if (limpio.length < 2) return limpio;
    return '${limpio.substring(0, limpio.length - 1)}-${limpio.substring(limpio.length - 1)}';
  }

  int _calcularEdad(DateTime nacimiento) {
    final hoy = DateTime.now();
    int edad = hoy.year - nacimiento.year;
    if (hoy.isBefore(DateTime(hoy.year, nacimiento.month, nacimiento.day))) {
      edad--;
    }
    return edad;
  }

  Future<void> registrar({
    required String rut,
    required String nombre,
    required DateTime fechaNacimiento,
    required String telefono,
    required String correo,
    required String contrasena,
  }) async {
    final rutId = normalizarRut(rut);

    final edad = _calcularEdad(fechaNacimiento);
    if (edad < edadMinima || edad > edadMaxima) {
      throw AuthException(
          'La fecha de nacimiento está fuera del rango permitido ($edadMinima a $edadMaxima años).');
    }

    // 1. Crea la cuenta. Firebase rechaza correos repetidos.
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: contrasena,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw AuthException('Ya existe una cuenta con este correo.');
      }
      throw AuthException('No se pudo crear la cuenta. Intenta nuevamente.');
    }

    // 2. Guarda usuario y donante. El RUT es el id, así no se duplica.
    final donanteRef = _db.collection('donantes').doc(rutId);
    final usuarioRef = _db.collection('usuarios').doc(cred.user!.uid);

    bool rutDuplicado = false;
    try {
      // La transacción devuelve true si el RUT ya existía; no lanza errores propios.
      rutDuplicado = await _db.runTransaction<bool>((tx) async {
        final existe = await tx.get(donanteRef);
        if (existe.exists) return true;
        tx.set(usuarioRef, {
          'rut': rutId,
          'nombre': nombre.trim(),
          'correo': correo.trim(),
          'telefono': telefono.trim(),
          'rol': 'donante',
          'fechaRegistro': FieldValue.serverTimestamp(),
        });
        tx.set(donanteRef, {
          'uid': cred.user!.uid,
          'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        });
        return false;
      });
    } catch (e) {
      await cred.user?.delete(); // deshace la cuenta si algo falló
      throw AuthException('No se pudo guardar el registro.');
    }

    if (rutDuplicado) {
      await cred.user?.delete(); // deshace la cuenta recién creada
      throw AuthException('Ya existe una cuenta con este RUT.');
    }
  }

  Future<void> iniciarSesion(String correo, String contrasena) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: contrasena,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        throw AuthException('Correo o contraseña incorrectos.');
      }
      throw AuthException('No se pudo iniciar sesión. Intenta nuevamente.');
    }
  }

  Future<void> cerrarSesion() => _auth.signOut();
}