import 'package:flutter/material.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/services/donacion_service.dart';
import 'package:hemocheck/utils/donacion_validators.dart';

/// Argumentos que recibe la ruta `/registrar-donacion`.
class RegistrarDonacionArgs {
  const RegistrarDonacionArgs({
    required this.evaluacion,
    required this.donanteRut,
    required this.tipoSangre,
    required this.sedeId,
    required this.profesionalId,
  });

  final Evaluacion? evaluacion;
  final String donanteRut;
  final TipoSangre? tipoSangre;
  final String sedeId;
  final String profesionalId;
}

/// Consulta si ya existe una donación para la cita. Solo se inyecta en tests;
/// en producción lo consulta el propio [DonacionService] en Firestore.
typedef ExisteDonacion = Future<bool> Function(String citaId);

String etiquetaTipoSangre(TipoSangre tipo) {
  switch (tipo) {
    case TipoSangre.aPos:
      return 'A+';
    case TipoSangre.aNeg:
      return 'A-';
    case TipoSangre.bPos:
      return 'B+';
    case TipoSangre.bNeg:
      return 'B-';
    case TipoSangre.abPos:
      return 'AB+';
    case TipoSangre.abNeg:
      return 'AB-';
    case TipoSangre.oPos:
      return 'O+';
    case TipoSangre.oNeg:
      return 'O-';
  }
}

class RegistrarDonacionScreen extends StatefulWidget {
  const RegistrarDonacionScreen({
    super.key,
    required this.evaluacion,
    required this.donanteRut,
    required this.tipoSangre,
    required this.sedeId,
    required this.profesionalId,
    this.service,
    this.existeDonacion,
  });

  final Evaluacion? evaluacion;
  final String donanteRut;
  final TipoSangre? tipoSangre;
  final String sedeId;
  final String profesionalId;

  // Inyectables para poder probar la pantalla sin Firebase.
  final DonacionService? service;
  final ExisteDonacion? existeDonacion;

  @override
  State<RegistrarDonacionScreen> createState() =>
      _RegistrarDonacionScreenState();
}

class _RegistrarDonacionScreenState extends State<RegistrarDonacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _volumenCtrl = TextEditingController();
  late final DonacionService _service;

  String? _errorAptitud;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DonacionService();
    // CU-17: verifica el estado apto vigente al abrir la pantalla.
    try {
      _service.verificarEstadoAptoVigente(widget.evaluacion);
    } on DonacionException catch (e) {
      _errorAptitud = e.mensaje;
    }
  }

  @override
  void dispose() {
    _volumenCtrl.dispose();
    super.dispose();
  }

  String _formatoFecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}-${f.month.toString().padLeft(2, '0')}-${f.year}';

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final yaExiste = widget.existeDonacion == null
          ? null
          : await widget.existeDonacion!(widget.evaluacion!.citaId);

      // CU-16: valida, crea donación + unidad + bitácora y los guarda
      // de forma atómica (todo o nada).
      final resultado = await _service.registrarDonacion(
        evaluacion: widget.evaluacion,
        tipoSangre: widget.tipoSangre,
        volumenMl: int.parse(_volumenCtrl.text.trim()),
        sedeId: widget.sedeId,
        profesionalId: widget.profesionalId,
        yaExisteDonacionEnCita: yaExiste,
      );

      if (!mounted) return;
      setState(() => _guardando = false); // apaga el indicador antes del diálogo
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Donación registrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código de bolsa: ${resultado.unidad.codigoBolsa}'),
              Text(
                  'Tipo de sangre: ${etiquetaTipoSangre(resultado.unidad.tipoSangre)}'),
              Text(
                  'Vence el: ${_formatoFecha(resultado.unidad.fechaVencimiento)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DonacionException catch (e) {
      if (!mounted) return;
      _mostrarError(e.mensaje);
    } catch (_) {
      if (!mounted) return;
      _mostrarError('No se pudo guardar la donación. No se realizó ningún cambio.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.tipoSangre;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Donación - HemoCheck')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text('Donante: ${widget.donanteRut}'),
                  subtitle: Text(
                    'Tipo de sangre: ${tipo == null ? 'No registrado' : etiquetaTipoSangre(tipo)}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorAptitud != null)
                Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: const Text('Donación bloqueada'),
                    subtitle: Text(_errorAptitud!),
                  ),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _volumenCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Volumen donado (ml)',
                          hintText: 'Ej: 450',
                          border: OutlineInputBorder(),
                        ),
                        validator: DonacionValidators.validateVolumen,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _guardando ? null : _confirmar,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _guardando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Confirmar Donación'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}