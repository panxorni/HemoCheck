import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hemocheck/models/bloque_horario.dart';
import 'package:hemocheck/models/sede.dart';
import 'package:hemocheck/services/auth_service.dart';
import 'package:hemocheck/services/citas_service.dart';

import 'bloque_horario_screen.dart';
import 'evaluacion_clinica_screen.dart';

class DashboardDonanteScreen extends StatefulWidget {
  const DashboardDonanteScreen({super.key});

  @override
  State<DashboardDonanteScreen> createState() => _DashboardDonanteScreenState();
}

class _DashboardDonanteScreenState extends State<DashboardDonanteScreen> {
  final CitasService _citasService = CitasService();
  late final List<Sede> _sedes;
  late Sede _sedeSeleccionada;
  late Future<List<BloqueHorario>> _horariosFuture;

  @override
  void initState() {
    super.initState();
    _sedes = Sede.ordenarPorDistancia(Sede.sedesDisponibles);
    _sedeSeleccionada = _sedes.first;
    _horariosFuture = _obtenerHorarios(_sedeSeleccionada.id);
  }

  // Nombre o correo con el que el donante aparece en los bloques
  String get _identificadorDonante {
    final usuario = FirebaseAuth.instance.currentUser;
    return usuario?.displayName ?? usuario?.email ?? 'Donante Anónimo';
  }

  // Leer horarios directamente desde Cloud Firestore
  Future<List<BloqueHorario>> _obtenerHorarios(String sedeId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('sedes')
        .doc(sedeId)
        .collection('horarios')
        .get();

    return snapshot.docs.map((doc) {
      final datos = doc.data();
      datos['id'] = doc.id; // Asigna el ID automático de Firestore
      datos['sedeId'] = sedeId;
      return BloqueHorario.fromJson(datos);
    }).toList();
  }

  void _recargar() {
    setState(() {
      _horariosFuture = _obtenerHorarios(_sedeSeleccionada.id);
    });
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  Future<void> _reservarCupo(BloqueHorario bloque) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      _mostrarError('Debes iniciar sesión para reservar');
      return;
    }

    final sede = _sedeSeleccionada;
    try {
      final reserva = await _citasService.reservar(
        donanteId: usuario.uid,
        identificador: _identificadorDonante,
        sedeId: sede.id,
        bloqueId: bloque.id,
      );
      if (!mounted) return;
      _recargar();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¡Reserva confirmada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código de reserva: ${reserva.codigoReserva}'),
              const SizedBox(height: 8),
              Text('Sede: ${sede.nombre}'),
              Text('Fecha: ${reserva.fecha}'),
              Text('Hora: ${reserva.horaInicio} - ${reserva.horaFin}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } on CitaException catch (e) {
      if (!mounted) return;
      _mostrarError(e.mensaje);
      _recargar();
    }
  }

  Future<void> _cancelarCupo(BloqueHorario bloque) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      _mostrarError('Debes iniciar sesión para cancelar');
      return;
    }

    final confirmado = await _confirmarAccion(
      titulo: 'Cancelar reserva',
      mensaje:
          '¿Seguro que quieres cancelar tu reserva? El cupo quedará libre para otros donantes.',
      textoConfirmar: 'Cancelar reserva',
    );
    if (!confirmado || !mounted) return;

    try {
      await _citasService.cancelar(
        donanteId: usuario.uid,
        identificador: _identificadorDonante,
        sedeId: _sedeSeleccionada.id,
        bloqueId: bloque.id,
      );
      if (!mounted) return;
      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada. El cupo ha sido liberado.'),
          backgroundColor: Colors.orange,
        ),
      );
    } on CitaException catch (e) {
      if (!mounted) return;
      _mostrarError(e.mensaje);
      _recargar();
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
            child: const Text('Volver'),
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

  Widget _selectorDeSede() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButton<Sede>(
        isExpanded: true,
        itemHeight: 64,
        value: _sedeSeleccionada,
        items: _sedes
            .map(
              (sede) => DropdownMenuItem<Sede>(
                value: sede,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sede.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${sede.direccion} · ${sede.distanciaKm.toStringAsFixed(1)} km',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (sede) {
          if (sede == null) return;
          setState(() {
            _sedeSeleccionada = sede;
            _horariosFuture = _obtenerHorarios(sede.id);
          });
        },
      ),
    );
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
      body: Column(
        children: [
          _selectorDeSede(),
          Expanded(
            child: FutureBuilder<List<BloqueHorario>>(
              future: _horariosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No hay horarios de donación disponibles.'),
                  );
                }
                final identificador = _identificadorDonante;
                final bloques = snapshot.data!;
                return ListView.builder(
                  itemCount: bloques.length,
                  itemBuilder: (context, index) {
                    final bloque = bloques[index];
                    return BloqueCard(
                      bloque: bloque,
                      yaInscrito: bloque.inscritos.contains(identificador),
                      onReservar: () => _reservarCupo(bloque),
                      onCancelar: () => _cancelarCupo(bloque),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'recargarBtn',
            onPressed: _recargar,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'evaluacionLoginBtn',
            backgroundColor: Colors.orange,
            tooltip: 'Evaluación clínica (PROVISIONAL)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EvaluacionClinicaScreen(),
                ),
              );
            },
            child: const Icon(Icons.medical_services),
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
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un bloque horario con su botón de reserva / cancelación.
class BloqueCard extends StatelessWidget {
  const BloqueCard({
    super.key,
    required this.bloque,
    required this.onReservar,
    required this.onCancelar,
    this.yaInscrito = false,
  });

  final BloqueHorario bloque;
  final bool yaInscrito;
  final VoidCallback onReservar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final cerrado = bloque.cerrado;
    final lleno = !bloque.tieneCapacidad;
    final disponibles = (bloque.capacidadMaxima - bloque.reservasActuales)
        .clamp(0, bloque.capacidadMaxima)
        .toInt();

    final String texto;
    final Color color;
    final VoidCallback? accion;
    if (cerrado) {
      texto = 'Cerrado';
      color = Colors.grey;
      accion = null;
    } else if (yaInscrito) {
      texto = 'Cancelar';
      color = Colors.grey.shade700;
      accion = onCancelar;
    } else if (lleno) {
      texto = 'Lleno';
      color = Colors.red;
      accion = null;
    } else {
      texto = 'Reservar';
      color = Colors.red;
      accion = onReservar;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          child: Icon(Icons.bloodtype_outlined, color: Colors.white),
        ),
        title: Text(
          '${bloque.fecha} | ${bloque.horaInicio} - ${bloque.horaFin}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Cupos: $disponibles disponibles'),
        trailing: ElevatedButton(
          onPressed: accion,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text(texto),
        ),
      ),
    );
  }
}
