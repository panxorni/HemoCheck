
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:hemocheck/models/bloque_horario.dart';
import 'package:hemocheck/utils/bloque_horario_validators.dart';


class BloqueHorarioScreen extends StatefulWidget {
  const BloqueHorarioScreen({super.key});

  @override
  State<BloqueHorarioScreen> createState() => _BloqueHorarioScreenState();
}

class _BloqueHorarioScreenState extends State<BloqueHorarioScreen> {
  // Controla qué vista se muestra
  bool _viendoLista = false;

  //Variables del Formulario
  final _formKey = GlobalKey<FormState>();
  final _fechaCtrl = TextEditingController();
  final _inicioCtrl = TextEditingController();
  final _finCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  DateTime? _fecha;
  bool _cargando = false;


  List<BloqueHorario> _bloques = [];
  bool _cargandoLista = false;


  @override
  void dispose() {
    _fechaCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    _capacidadCtrl.dispose();
    super.dispose();
  }

  // Alterna entre vistas y recarga los datos si se esta en la lista
  void _alternarVista() {
    setState(() {
      _viendoLista = !_viendoLista;
    });
    if (_viendoLista) {
      _cargarBloques();
    }
  }

  // --- Lógica de Red (GET y POST) ---
  Future<void> _cargarBloques() async {
    setState(() => _cargandoLista = true);
    try {
      // Se piden todos los documentos de la colección 'horarios' en la sede '123'
      final snapshot = await FirebaseFirestore.instance
          .collection('sedes')
          .doc('123')
          .collection('horarios')
          .get();

      // Se transforma cada documento de Firebase en objeto BloqueHorario
      final listaCargada = snapshot.docs.map((doc) {
        final datos = doc.data();
        datos['id'] = doc.id; // Firebase genera un ID único automático por documento
        return BloqueHorario.fromJson(datos);
      }).toList();

      setState(() {
        _bloques = listaCargada;
      });
    } catch (e) {
      if (!mounted) return;
      _mensaje('Error al cargar desde Firebase: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargandoLista = false);
    }
  }

  Future<void> _enviarAlServicio(Map<String, dynamic> payload) async {
    // Apunta a la colección 'horarios' dentro del documento de la sede '123'
    final coleccion = FirebaseFirestore.instance
        .collection('sedes')
        .doc('123')
        .collection('horarios');

    await coleccion.add({
      ...payload,
      'sedeId': '123',
      'reservasActuales': 0,
      'inscritos': <String>[],
      'cerrado': false,
    });
  }
  Future<void> _sacarDonante(BloqueHorario bloque, String donante) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('sedes')
          .doc('123')
          .collection('horarios')
          .doc(bloque.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('El bloque no existe.');

        final datos = snapshot.data()!;
        final reservasActuales = datos['reservasActuales'] as int? ?? 0;

        transaction.update(docRef, {
          'reservasActuales': reservasActuales > 0 ? reservasActuales - 1 : 0,
          'inscritos': FieldValue.arrayRemove([donante]),
        });
      });

      _mensaje('Se ha removido a $donante del bloque.');
      await _cargarBloques();
    } catch (e) {
      _mensaje('Error al remover donante: $e', error: true);
    }
  }
  Future<void> _alternarEstadoBloque(BloqueHorario bloque) async {
    try {
      final nuevoEstado = !bloque.cerrado;
      await FirebaseFirestore.instance
          .collection('sedes')
          .doc('123')
          .collection('horarios')
          .doc(bloque.id)
          .update({'cerrado': nuevoEstado});

      _mensaje(
        nuevoEstado
            ? 'Bloque cerrado: ya no admite nuevas reservas.'
            : 'Bloque reabierto para reservas.',
      );
      await _cargarBloques();
    } catch (e) {
      _mensaje('Error al cambiar estado: $e', error: true);
    }
  }
  //Lógica del Formulario
  String _dos(int n) => n.toString().padLeft(2, '0');
  String _formatHora(TimeOfDay t) => '${_dos(t.hour)}:${_dos(t.minute)}';

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: hoySinHora,
      lastDate: DateTime(hoy.year + 5),
    );
    if (elegida == null) return;
    setState(() {
      _fecha = elegida;
      _fechaCtrl.text =
      '${_dos(elegida.day)}-${_dos(elegida.month)}-${elegida.year}';
    });
  }

  Future<void> _elegirHora(
      TextEditingController ctrl,
      TimeOfDay inicial,
      ) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: inicial,
    );
    if (elegida == null) return;
    setState(() => ctrl.text = _formatHora(elegida));
  }

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      _mensaje('Revisa los campos marcados', error: true);
      return;
    }

    final f = _fecha!;
    final payload = {
      'fecha': '${f.year}-${_dos(f.month)}-${_dos(f.day)}',
      'horaInicio': _inicioCtrl.text,
      'horaFin': _finCtrl.text,
      'capacidadMaxima': int.parse(_capacidadCtrl.text.trim()),
    };

    setState(() => _cargando = true);
    try {
      await _enviarAlServicio(payload);
      if (!mounted) return;
      _mensaje('Bloque horario guardado correctamente');
      _formKey.currentState!.reset();
      _fecha = null;
      _fechaCtrl.clear();
      _inicioCtrl.clear();
      _finCtrl.clear();
      _capacidadCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      _mensaje(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: Text(
          _viendoLista
              ? 'Horarios e Inscritos - HemoCheck'
              : 'Nuevo bloque horario - HemoCheck',
        ),
        actions: [
          // Botón para alternar entre vistas
          TextButton.icon(
            onPressed: _alternarVista,
            icon: Icon(_viendoLista ? Icons.add_circle_outline : Icons.list_alt),
            label: Text(_viendoLista ? 'Crear nuevo' : 'Ver creados'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _viendoLista ? _buildListaHorarios() : _buildFormulario(),
    );
  }

  //Formulario original
  Widget _buildFormulario() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _fechaCtrl,
                readOnly: true,
                onTap: _cargando ? null : _elegirFecha,
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: BloqueHorarioValidators.validateFecha,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _inicioCtrl,
                readOnly: true,
                onTap: _cargando
                    ? null
                    : () => _elegirHora(
                  _inicioCtrl,
                  const TimeOfDay(hour: 9, minute: 0),
                ),
                decoration: const InputDecoration(
                  labelText: 'Hora de inicio',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                validator: BloqueHorarioValidators.validateHoraInicio,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _finCtrl,
                readOnly: true,
                onTap: _cargando
                    ? null
                    : () => _elegirHora(
                  _finCtrl,
                  const TimeOfDay(hour: 10, minute: 0),
                ),
                decoration: const InputDecoration(
                  labelText: 'Hora de fin',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time_filled),
                ),
                validator: (v) => BloqueHorarioValidators.validateHoraFin(
                  _inicioCtrl.text,
                  v,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacidadCtrl,
                enabled: !_cargando,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacidad máxima de citas',
                  hintText: 'Ej: 20',
                  border: OutlineInputBorder(),
                ),
                validator: BloqueHorarioValidators.validateCapacidad,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _cargando
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Guardar bloque'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Lista de horarios creados y asistentes
  Widget _buildListaHorarios() {
    if (_cargandoLista) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bloques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No hay bloques horarios creados aún.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _cargarBloques,
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarBloques,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _bloques.length,
        itemBuilder: (context, index) {
          final bloque = _bloques[index];
          final cuposOcupados = bloque.reservasActuales;
          final lleno = cuposOcupados >= bloque.capacidadMaxima;

          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            color: bloque.cerrado ? Colors.grey.shade200 : null,
            child: ExpansionTile(
              leading: Icon(
                bloque.cerrado ? Icons.lock : Icons.event_available,
                color: bloque.cerrado
                    ? Colors.grey.shade700
                    : (lleno ? Colors.red : Colors.green),
              ),
              title: Text(
                '${bloque.fecha}  |  ${bloque.horaInicio} - ${bloque.horaFin}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: bloque.cerrado ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                bloque.cerrado
                    ? 'CERRADO • Cupos: $cuposOcupados / ${bloque.capacidadMaxima}'
                    : 'Cupos ocupados: $cuposOcupados / ${bloque.capacidadMaxima}',
              ),
              children: [
                const Divider(height: 1),
                // Botón administrativo para cerrar o reabrir el bloque
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estado del bloque:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _alternarEstadoBloque(bloque),
                        icon: Icon(
                          bloque.cerrado ? Icons.lock_open : Icons.lock_outline,
                          size: 18,
                          color: bloque.cerrado ? Colors.green : Colors.red,
                        ),
                        label: Text(
                          bloque.cerrado ? 'Reabrir bloque' : 'Cerrar bloque',
                          style: TextStyle(
                            color: bloque.cerrado ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lista de inscritos con opción para sacarlos
                if (bloque.inscritos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      cuposOcupados > 0
                          ? 'Hay $cuposOcupados reserva(s) registrada(s) sin nombre.'
                          : 'Aún no hay donantes inscritos en este bloque.',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ...bloque.inscritos.map(
                        (donante) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, size: 20),
                      title: Text(donante),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        tooltip: 'Sacar del bloque',
                        onPressed: () => _sacarDonante(bloque, donante),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}