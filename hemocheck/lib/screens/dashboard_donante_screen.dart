import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hemocheck/models/bloque_horario.dart';
import 'package:hemocheck/services/auth_service.dart';

import 'bloque_horario_screen.dart';

class DashboardDonanteScreen extends StatefulWidget {
  const DashboardDonanteScreen({super.key});

  @override
  State<DashboardDonanteScreen> createState() => _DashboardDonanteScreenState();
}

class _DashboardDonanteScreenState extends State<DashboardDonanteScreen> {
  final String sedeId = "123";
  late Future<List<BloqueHorario>> _horariosFuture;

  @override
  void initState() {
    super.initState();
    _horariosFuture = _obtenerHorarios(sedeId);
  }

  // Leer horarios directamente desde Cloud Firestore
  Future<List<BloqueHorario>> _obtenerHorarios(String id) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('sedes')
        .doc(id)
        .collection('horarios')
        .get();

    return snapshot.docs.map((doc) {
      final datos = doc.data();
      datos['id'] = doc.id; // Asigna el ID automático de Firestore
      return BloqueHorario.fromJson(datos);
    }).toList();
  }

  //Reservar cupo actualizando el documento en Cloud Firestore
  Future<void> _reservarCupo(BloqueHorario bloque) async {
    if (bloque.reservasActuales >= bloque.capacidadMaxima) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este bloque ya está lleno')),
      );
      return;
    }

    // Obtiene el correo/nombre del usuario logueado o usa uno genérico si no hay sesión
    final usuario = FirebaseAuth.instance.currentUser;
    final identificadorDonante =
        usuario?.displayName ?? usuario?.email ?? 'Donante Anónimo';

    if (bloque.inscritos.contains(identificadorDonante)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya tienes una reserva en este bloque')),
      );
      return;
    }
    try {
      final docRef = FirebaseFirestore.instance
          .collection('sedes')
          .doc(sedeId)
          .collection('horarios')
          .doc(bloque.id);

      await docRef.update({
        'reservasActuales': FieldValue.increment(1),
        'inscritos': FieldValue.arrayUnion([identificadorDonante]),
      });

      // Recarga la lista visualmente con tu _horariosFuture
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reservar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  Future<void> _cancelarCupo(BloqueHorario bloque) async {
    final usuario = FirebaseAuth.instance.currentUser;
    final identificadorDonante =
        usuario?.displayName ?? usuario?.email ?? 'Donante Anónimo';

    try {
      final docRef = FirebaseFirestore.instance
          .collection('sedes')
          .doc(sedeId)
          .collection('horarios')
          .doc(bloque.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('El bloque ya no existe.');

        final datos = snapshot.data()!;
        if (datos['cerrado'] == true) {
          throw Exception('Este bloque horario fue cerrado por la sede.');
        }
        final inscritosActuales = List<String>.from(datos['inscritos'] ?? []);
        final reservasActuales = datos['reservasActuales'] as int? ?? 0;

        if (!inscritosActuales.contains(identificadorDonante)) {
          throw Exception('No tienes una reserva activa en este bloque.');
        }

        transaction.update(docRef, {
          'reservasActuales': reservasActuales > 0 ? reservasActuales - 1 : 0,
          'inscritos': FieldValue.arrayRemove([identificadorDonante]),
        });
      });

      setState(() {
        _horariosFuture = _obtenerHorarios(sedeId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva cancelada. El cupo ha sido liberado.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<bool> _confirmarAccion({
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
    Color colorConfirmar = Colors.red,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorConfirmar,
              foregroundColor: Colors.white,
            ),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No hay horarios de donación disponibles."),
            );
          }
          final usuario = FirebaseAuth.instance.currentUser;
          final identificadorDonante =
              usuario?.displayName ?? usuario?.email ?? 'Donante Anónimo';
          final bloques = snapshot.data!;
          return ListView.builder(
            itemCount: bloques.length,
            itemBuilder: (context, index) {
              final bloque = bloques[index];
              final lleno = bloque.reservasActuales >= bloque.capacidadMaxima;
              final yaInscrito = bloque.inscritos.contains(identificadorDonante);
              final cerrado = bloque.cerrado;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.bloodtype_outlined, color: Colors.white),
                  ),
                  title: Text(
                    "${bloque.fecha} | ${bloque.horaInicio} - ${bloque.horaFin}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Cupos: ${bloque.capacidadMaxima - bloque.reservasActuales} disponibles",
                  ),
                  trailing: ElevatedButton(
                    onPressed: cerrado
                        ? null
                        : (yaInscrito
                        ? () => _cancelarCupo(bloque)
                        : (lleno ? null : () => _reservarCupo(bloque))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cerrado
                          ? Colors.grey
                          : (yaInscrito ? Colors.grey.shade700 : Colors.red),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      cerrado
                          ? "Cerrado"
                          : (yaInscrito
                          ? "Cancelar"
                          : (lleno ? "Lleno" : "Reservar")),
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
          FloatingActionButton(
            heroTag: 'recargarBtn',
            onPressed: () {
              setState(() {
                _horariosFuture = _obtenerHorarios(sedeId);
              });
            },
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'crearBtn',
            backgroundColor: Colors.orange,
            tooltip: 'Crear nuevo bloque (PROVISIONAL)',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BloqueHorarioScreen(),
                ),
              );
              // Recarga automáticamente al volver de crear un bloque
              setState(() {
                _horariosFuture = _obtenerHorarios(sedeId);
              });
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}