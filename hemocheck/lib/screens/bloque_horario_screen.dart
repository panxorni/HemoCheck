import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hemocheck/utils/bloque_horario_validators.dart';
import 'package:http/http.dart' as http;
//Nota si ven incompatibilidades, colocar "flutter pub add http" desde la terminal apuntando a la carpeta "hemocheck" CON LA MINUSCULA,YA QUE NO DEBE INVOLUCRAR AL BACK END
class BloqueHorarioScreen extends StatefulWidget {
  const BloqueHorarioScreen({super.key});

  @override
  State<BloqueHorarioScreen> createState() => _BloqueHorarioScreenState();
}

class _BloqueHorarioScreenState extends State<BloqueHorarioScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fechaCtrl = TextEditingController();
  final _inicioCtrl = TextEditingController();
  final _finCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();

  DateTime? _fecha;
  bool _cargando = false;

  @override
  void dispose() {
    _fechaCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    _capacidadCtrl.dispose();
    super.dispose();
  }

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
      _fechaCtrl.text = '${_dos(elegida.day)}-${_dos(elegida.month)}-${elegida.year}';
    });
  }

  Future<void> _elegirHora(TextEditingController ctrl, TimeOfDay inicial) async {
    final elegida = await showTimePicker(context: context, initialTime: inicial);
    if (elegida == null) return;
    setState(() => ctrl.text = _formatHora(elegida));
  }

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }


  Future<void> _enviarAlServicio(Map<String, dynamic> payload) async {
    ///en caso de hacer build de movil cambiar el parse por "http://10.0.2.2:8080/sedes/123/horarios"
    final url = Uri.parse("http://localhost:8080/sedes/123/horarios");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
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
      appBar: AppBar(title: const Text('Nuevo bloque horario - HemoCheck')),
      body: Padding(
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
                          _inicioCtrl, const TimeOfDay(hour: 9, minute: 0)),
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
                          _finCtrl, const TimeOfDay(hour: 10, minute: 0)),
                  decoration: const InputDecoration(
                    labelText: 'Hora de fin',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time_filled),
                  ),
                  validator: (v) =>
                      BloqueHorarioValidators.validateHoraFin(_inicioCtrl.text, v),
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
      ),
    );
  }
}