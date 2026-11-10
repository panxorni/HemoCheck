import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/utils/validators.dart'; 

void main() {
  group('Validación de Registro - HemoCheck', () {
    test('Test 1 (Validación de RUT): Retorna error con RUT inválido', () {
      // Arrange
      const invalidRut = "12345678-9";
      
      // Act
      final result = Validators.validateRut(invalidRut);
      
      // Assert
      expect(result, isNotNull); 
      expect(result, 'RUT inválido'); // se afirma que devuelve el mensaje de error esperado
    });

    test('Test 1.1 (Validación de RUT): Retorna null con RUT válido', () {
      // Arrange (Usa un RUT genérico válido para pruebas, ej: 11.111.111-1)
      const validRut = "11111111-1"; 
      
      // Act
      final result = Validators.validateRut(validRut);
      
      // Assert
      expect(result, isNull); // Si es válido, el validador debe retornar null
    });
  });
  group('Validación de Correo - HemoCheck', () {
    test('Retorna error si el correo está vacío', () {
      expect(Validators.validateEmail(''), 'El correo es obligatorio');
    });

    test('Retorna error con formato de correo inválido', () {
      expect(Validators.validateEmail('usuario@dominio'), 'Correo inválido');
      expect(Validators.validateEmail('correo.com'), 'Correo inválido');
    });

    test('Retorna null con correo válido', () {
      expect(Validators.validateEmail('donante@hemocheck.cl'), isNull);
    });
  });

  group('Validación de Contraseña - HemoCheck', () {
    test('Retorna error si la contraseña está vacía', () {
      expect(Validators.validatePassword(''), 'La contraseña es obligatoria');
    });

    test('Retorna error si tiene menos de 6 caracteres', () {
      expect(Validators.validatePassword('A1bcd'), 'Debe tener al menos 6 caracteres');
    });

    test('Retorna error si no tiene mayúsculas', () {
      expect(Validators.validatePassword('hemo2026'), 'Debe incluir al menos una mayúscula');
    });

    test('Retorna error si no tiene números', () {
      expect(Validators.validatePassword('HemoCheck'), 'Debe incluir al menos un número');
    });

    test('Retorna null con contraseña válida (mínimo 6, una mayúscula, un número)', () {
      expect(Validators.validatePassword('Hemo2026'), isNull);
    });
  });
}
