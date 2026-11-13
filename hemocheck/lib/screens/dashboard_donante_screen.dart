import 'package:flutter/material.dart';
import 'package:hemocheck/models/bloque_horario.dart';
import 'package:hemocheck/services/auth_service.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'bloque_horario_screen.dart';

class DashboardDonanteScreen extends StatefulWidget {
  const DashboardDonanteScreen({super.key});

  @override
  State<DashboardDonanteScreen> createState() => _DashboardDonanteScreenState();
}

class _DashboardDonanteScreenState extends State<DashboardDonanteScreen> {
  final String sedeId= "123";
  late Future<List<BloqueHorario>> _horariosFuture;

  @override
  void initState(){
    super.initState();
    _horariosFuture = _obtenerHorarios(sedeId);
  }
  Future<List<BloqueHorario>> _obtenerHorarios(String id) async{
///en caso de hacer build de movil cambiar el parse por "http://10.0.2.2:8080/sedes/$id/horario"
    final url = Uri.parse('http://localhost:8080/sedes/$id/horarios');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> datos = jsonDecode(response.body);
      return datos.map((json) => BloqueHorario.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar horarios: ${response.statusCode}');
    }
  }
  Future<void> _reservarCupo(BloqueHorario bloque) async {
    //valida si hay cupos
    if (bloque.reservasActuales >= bloque.capacidadMaxima) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este bloque ya está lleno')),
      );
      return;
    }

    //Apunta a la ruta PUT específica del bloque
    //en caso de hacer build de MOVIL cambiar el parse por "http://10.0.2.2:8080/sedes/$sedeId/horarios/${bloque.id}"
    final url = Uri.parse('http://localhost:8080/sedes/$sedeId/horarios/${bloque.id}');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // Sumamos 1 a las reservas actuales
          'reservasActuales': bloque.reservasActuales + 1,
        }),
      );

      if (response.statusCode == 200) {
        // Si tuvo éxito, recarga la lista visualmente
        setState(() {
          _horariosFuture = _obtenerHorarios(sedeId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Reserva confirmada con éxito!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Error al actualizar en el servidor');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HemoCheck - Donante'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await AuthService().cerrarSesion();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (r) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<BloqueHorario>>(
        future: _horariosFuture,
        builder: (context, snapshot){
          if ( snapshot.connectionState== ConnectionState.waiting){
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red),));
          }
          else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay horarios de donación disponibles."));
          }
          final bloques = snapshot.data!;
          return ListView.builder(
            itemCount: bloques.length,
            itemBuilder: (context, index){
              final bloque = bloques[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading:const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child:  Icon(Icons.bloodtype_outlined , color: Colors.white),
                  ),
                  title: Text(
                    "${bloque.fecha} | ${bloque.horaInicio} - ${bloque.horaFin}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Cupos: ${bloque.capacidadMaxima - bloque.reservasActuales} disponibles"),
                  trailing: ElevatedButton(
                    onPressed: (bloque.reservasActuales >= bloque.capacidadMaxima)
                      ? null
                      : () => _reservarCupo(bloque),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    (bloque.reservasActuales >= bloque.capacidadMaxima) ? "Lleno" : "Reservar",
                  ),
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          //Botón para recargar la lista
          FloatingActionButton(
            heroTag: 'recargarBtn', // Necesario cuando hay dos botones flotantes
            onPressed: () {
              setState(() {
                _horariosFuture = _obtenerHorarios(sedeId);
              });
            },
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16), // Espacio entre los botones

          //BOTON PROVISIONAL, ESTO ESTA AQUI SOLO PARA NAVEGAR ENTRE PANTALLAS Y HACER PRUEBAS
          FloatingActionButton(
            heroTag: 'crearBtn',
            backgroundColor: Colors.orange,
            tooltip: 'Crear nuevo bloque (PROVISIONAL)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BloqueHorarioScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );

  }
}


