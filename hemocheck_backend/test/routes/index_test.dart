
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/sedes/[sedeId]/horarios/index.dart' as route;

class MockRequestContext extends Mock implements RequestContext {}
class MockRequest extends Mock implements Request {}

void main() {

  group('POST /sedes/[sedeId]/horarios', () {
    late MockRequestContext context;
    late MockRequest request;

    setUp(() {
      context = MockRequestContext();
      request = MockRequest();

      // Cada vez que el código pida el context.request, le da el request simulado
      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.post);
    });


    test('Test 1 (Capacidad Inválida): Devuelve 400 si la capacidad es 0 o negativa', () async {
      //  Envia el token, pero con una capacidad de 0
      when(() => request.headers).thenReturn({'Authorization': 'Bearer token_valido'});
      when(() => request.json()).thenAnswer((_) async => {
        'fecha': '2026-11-20',
        'horaInicio': '09:00',
        'horaFin': '13:00',
        'capacidadMaxima': 0 //Dato inválido
      });

      final response = await route.onRequest(context, 'sede-123');

      //Afirma que el sistema lo rechaza con 400
      expect(response.statusCode, equals(400));
    });

    test('Test 2 (Creación Exitosa): Devuelve 201 y guarda el bloque con datos válidos', () async {
      // Token válido y payload perfecto
      when(() => request.headers).thenReturn({'Authorization': 'Bearer token_valido'});
      when(() => request.json()).thenAnswer((_) async => {
        'fecha': '2026-11-20',
        'horaInicio': '09:00',
        'horaFin': '13:00',
        'capacidadMaxima': 30
      });

      final response = await route.onRequest(context, 'sede-123');

      //Afirma que el estado es 201 Created
      expect(response.statusCode, equals(201));

      final body = await response.json() as Map<String, dynamic>;
      expect(body['capacidadMaxima'], equals(30));
      expect(body['sedeId'], equals('sede-123')); // Asegura que inyectó la sede correcta
      expect(body.containsKey('id'), isTrue); // Asegura que generó un ID
    });
  });
}
