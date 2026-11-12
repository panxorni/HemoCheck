import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/utils/bloque_horario_validators.dart';

void main() {
  group('Validación de Capacidad - Bloque Horario', () {
    test('Retorna error si está vacía', () {
      expect(BloqueHorarioValidators.validateCapacidad(''), 'La capacidad es obligatoria');
    });

    test('Retorna error si es 0 o negativa', () {
      expect(BloqueHorarioValidators.validateCapacidad('0'), 'Debe ser mayor a 0');
      expect(BloqueHorarioValidators.validateCapacidad('-3'), 'Debe ser mayor a 0');
    });

    test('Retorna error si no es un entero', () {
      expect(BloqueHorarioValidators.validateCapacidad('abc'), 'Debe ser un número entero');
      expect(BloqueHorarioValidators.validateCapacidad('2.5'), 'Debe ser un número entero');
    });

    test('Retorna null con un entero mayor a 0', () {
      expect(BloqueHorarioValidators.validateCapacidad('20'), isNull);
    });
  });

  group('Validación de Hora de Fin - Bloque Horario', () {
    test('Retorna error si no se eligió la hora de fin', () {
      expect(BloqueHorarioValidators.validateHoraFin('09:00', ''), 'Selecciona la hora de fin');
    });

    test('Retorna error si fin es igual o anterior al inicio', () {
      const msg = 'La hora de fin debe ser posterior a la de inicio';
      expect(BloqueHorarioValidators.validateHoraFin('09:00', '09:00'), msg);
      expect(BloqueHorarioValidators.validateHoraFin('09:00', '08:30'), msg);
    });

    test('Retorna null si fin es posterior al inicio', () {
      expect(BloqueHorarioValidators.validateHoraFin('09:00', '10:00'), isNull);
    });
  });

    group('Validación de Fecha - Bloque Horario', () {
    test('Retorna error si no se eligió la fecha', () {
      expect(BloqueHorarioValidators.validateFecha(''), 'Selecciona la fecha');
      expect(BloqueHorarioValidators.validateFecha(null), 'Selecciona la fecha');
    });

    test('Retorna null si hay fecha', () {
      expect(BloqueHorarioValidators.validateFecha('12-11-2026'), isNull);
    });
  });

  group('Validación de Hora de Inicio - Bloque Horario', () {
    test('Retorna error si no se eligió la hora de inicio', () {
      expect(BloqueHorarioValidators.validateHoraInicio(''),
          'Selecciona la hora de inicio');
      expect(BloqueHorarioValidators.validateHoraInicio(null),
          'Selecciona la hora de inicio');
    });

    test('Retorna null si hay hora de inicio', () {
      expect(BloqueHorarioValidators.validateHoraInicio('09:00'), isNull);
    });
  });
}