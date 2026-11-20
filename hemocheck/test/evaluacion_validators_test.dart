import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/utils/evaluacion_validators.dart';


void main() {


  final hoy = DateTime(2026, 11, 20);


  group('Validacion del Peso - Evaluacion', () {
    test('Peso menor a 50 kg retorna mensaje de bloqueo', () {
      expect(
        EvaluacionValidators.validatePeso('49.5'),
        'Bloqueo clínico: el peso mínimo para donar es 50 kg',
        );
    });


    test('Peso de 50 kg es valido', () {
      expect(
        EvaluacionValidators.validatePeso('50'),
        isNull,
        );
    });


    test('Rechaza vacio, texto y valores no finitos', () {
      expect(EvaluacionValidators.validatePeso(null), isNotNull);
      expect(EvaluacionValidators.validatePeso(''), isNotNull);
      expect(EvaluacionValidators.validatePeso('abc'), isNotNull);
      expect(EvaluacionValidators.validatePeso('NaN'), isNotNull);
      expect(EvaluacionValidators.validatePeso('Infinity'), isNotNull);
     
    });


    test('Acepta coma decimal', () {
      expect(EvaluacionValidators.validatePeso('65,5'), isNull);
    });
  });


  group('Validacion autorizacion parental - Evaluacion', () {

    final fecha17Anos = DateTime(2009, 3, 15);

    test('17 años sin autorizacion retorna mensaje de bloqueo', () {
      expect(
        EvaluacionValidators.validateAutorizacionParental(fecha17Anos, false, hoy: hoy), 
        'Bloqueo clínico: donante de 17 años requiere autorización parental',
        );
    });

    test('17 años con autorizacion retorna null', () {
      expect(
        EvaluacionValidators.validateAutorizacionParental(fecha17Anos, true, hoy: hoy), 
        isNull,
      );
    });

    test('Solo se  exige a los 17 años exactos' , () {
      expect(
        EvaluacionValidators.requiereAutorizacionParental(DateTime(2009, 11, 20), hoy: hoy), 
        isTrue,
        );

      // Cumple 18 hoy (ya no requiere)
      expect(
        EvaluacionValidators.requiereAutorizacionParental(DateTime(2008, 11, 20)), 
        isFalse,
        );
    });
  });

  group('Validacion de la Edad Minima', () {
    test('Menor de 17 años retorna mensaje de bloqueo', () {
      expect(
        EvaluacionValidators.validateEdadMinima(DateTime(2010, 3, 15), hoy: hoy), 
        'Bloqueo clínico: la edad mínima para donar es 17 años',
        );

      expect(
        EvaluacionValidators.validateEdadMinima(DateTime(2011, 3, 15), hoy: hoy), 
        isNotNull,
        );
    });
  
    test('17 años o mas retorna null', () {
      expect(
        EvaluacionValidators.validateEdadMinima(DateTime(2009, 3, 15), hoy: hoy), 
        isNull,
        );

      expect(
        EvaluacionValidators.validateEdadMinima(DateTime(2000, 3, 15), hoy: hoy), 
        isNull,
        );
    });

    test('Caso borde: cumple 17 hoy pasa, cumple mañana no', () {
      expect(
        EvaluacionValidators.validateEdadMinima(DateTime(2009, 11, 20), hoy: hoy), 
        isNull,
        );
      
      expect(
        EvaluacionValidators.validateEdadMinima(DateTime(2009, 11, 21), hoy: hoy), 
        isNotNull,
        );
    });
  });

  group('Validacion de la Fecha de Habilitacion - Evaluacion', () {
    
    test('Diferido sin fecha retorna error', () {
      expect(
        EvaluacionValidators.validateFechaHabilitacion(
            ResultadoEvaluacion.diferidoTemporal, null, hoy: hoy),
        isNotNull,
      );
    });

    test('Diferido con fecha de ayer o de hoy retorna error', () {
      expect(
        EvaluacionValidators.validateFechaHabilitacion(
            ResultadoEvaluacion.diferidoTemporal, DateTime(2026, 11, 19),
            hoy: hoy),
        isNotNull,
      );

      expect(
        EvaluacionValidators.validateFechaHabilitacion(
            ResultadoEvaluacion.diferidoTemporal, DateTime(2026, 11, 20),
            hoy: hoy),
        isNotNull,
      );
    });

    test('Diferido con fecha de mañana retorna null', () {
      expect(
        EvaluacionValidators.validateFechaHabilitacion(
            ResultadoEvaluacion.diferidoTemporal, DateTime(2026, 11, 21),
            hoy: hoy),
        isNull,
      );
    });

    test('Otros resultados no exigen fecha', () {
      expect(
        EvaluacionValidators.validateFechaHabilitacion(
            ResultadoEvaluacion.apto, null, hoy: hoy),
        isNull,
      );

      expect(
        EvaluacionValidators.validateFechaHabilitacion(
            ResultadoEvaluacion.rechazadoPermanente, null, hoy: hoy),
        isNull,
      );
    });
  });


  group('privacidad (RNF-06)', () {
    test('toJson no contiene datos del cuestionario clínico', () {
      final evaluacion = Evaluacion(
        citaId: 'cita-1',
        donanteRut: '12345678-5',
        profesionalId: 'prof-1',
        fecha: hoy,
        resultado: ResultadoEvaluacion.apto,
      );

      final keys = evaluacion.toJson().keys;

      expect(keys, isNot(contains('cuestionario')));
      expect(keys, isNot(contains('respuestas')));
      expect(
        keys.toSet(),
        {
          'citaId',
          'donanteRut',
          'profesionalId',
          'fecha',
          'resultado',
          'fechaHabilitacion',
        },
      );
    });

    test('fromJson(toJson) conserva los datos', () {
      final original = Evaluacion(
        citaId: 'cita-1',
        donanteRut: '12345678-5',
        profesionalId: 'prof-1',
        fecha: hoy,
        resultado: ResultadoEvaluacion.diferidoTemporal,
        fechaHabilitacion: DateTime(2026, 12, 1),
      );

      final copia = Evaluacion.fromJson(original.toJson());

      expect(copia.resultado, ResultadoEvaluacion.diferidoTemporal);
      expect(copia.fechaHabilitacion, DateTime(2026, 12, 1));
      expect(copia.citaId, 'cita-1');
    });

        test('toJson incluye fechaHabilitacion en null cuando no aplica', () {
      final evaluacion = Evaluacion(
        citaId: 'cita-1',
        donanteRut: '12345678-5',
        profesionalId: 'prof-1',
        fecha: hoy,
        resultado: ResultadoEvaluacion.apto,
      );

      final json = evaluacion.toJson();

      expect(json.containsKey('fechaHabilitacion'), isTrue);
      expect(json['fechaHabilitacion'], isNull);
    });

    test('toJson incluye fechaHabilitacion como texto ISO cuando hay fecha', () {
      final evaluacion = Evaluacion(
        citaId: 'cita-1',
        donanteRut: '12345678-5',
        profesionalId: 'prof-1',
        fecha: hoy,
        resultado: ResultadoEvaluacion.diferidoTemporal,
        fechaHabilitacion: DateTime(2026, 12, 1),
      );

      expect(
        evaluacion.toJson()['fechaHabilitacion'],
        DateTime(2026, 12, 1).toIso8601String(),
      );
    });
  });
}