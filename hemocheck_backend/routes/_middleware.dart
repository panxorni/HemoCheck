import 'package:dart_frog/dart_frog.dart';

// Cabeceras de seguridad requeridas por los navegadores web
const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Permite peticiones de cualquier lugar
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
};

Handler middleware(Handler handler) {
  return (context) async {
    // Manejar las peticiones de pre-vuelo (Preflight OPTIONS)
    // El navegador siempre envía un "OPTIONS" primero para preguntar si tiene permiso.
    if (context.request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: corsHeaders);
    }

    //Procesar la petición real (GET, POST, etc.)
    final response = await handler(context);

    //Inyectar las cabeceras CORS a la respuesta antes de enviarla a Flutter
    return response.copyWith(
      headers: {
        ...response.headers,
        ...corsHeaders,
      },
    );
  };
}