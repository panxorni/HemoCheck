import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hemocheck/models/cita.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/services/auth_service.dart';
import 'package:hemocheck/services/evaluacion_service.dart';
import 'package:hemocheck/utils/evaluacion_validators.dart';
import 'package:hemocheck/utils/validators.dart';

class EvaluacionClinicaScreen extends StatefulWidget {
  const EvaluacionClinicaScreen({
    super.key,
    this.fechaNacimientoDonante,
    this.evaluacionService,
    this.firestore,
    this.authService,
  });

  final DateTime? fechaNacimientoDonante;
  final EvaluacionService? evaluacionService;
  final FirebaseFirestore? firestore;
  final AuthService? authService;

  @override
  State<EvaluacionClinicaScreen> createState() => _EvaluacionClinicaScreenState();
}

class _EvaluacionClinicaScreenState extends State<EvaluacionClinicaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _rutCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _fechaHabCtrl = TextEditingController();

  late final EvaluacionService _evaluacionService;
  late final FirebaseFirestore _firestore;
  late final AuthService _authService;

  Cita? _citaActual;
  DateTime? _fechaNacimientoDonante;
  TipoSangre? _tipoSangre;
  ResultadoEvaluacion? _resultado;
  DateTime? _fechaHabilitacion;
  bool _autorizacionParental = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _authService = widget.authService ?? AuthService(db: _firestore);
    _evaluacionService =
        widget.evaluacionService ?? EvaluacionService(firestore: _firestore);
    _fechaNacimientoDonante = widget.fechaNacimientoDonante;
  }

  @override
  void dispose() {
    _rutCtrl.dispose();
    _pesoCtrl.dispose();
    _fechaHabCtrl.dispose();
    super.dispose();
  }

  String _etiquetaTipoSangre(TipoSangre tipo) {
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

  String _etiquetaResultado(ResultadoEvaluacion res) {
    switch (res) {
      case ResultadoEvaluacion.apto:
        return 'Apto';
      case ResultadoEvaluacion.diferidoTemporal:
        return 'Diferido temporalmente';
      case ResultadoEvaluacion.rechazadoPermanente:
        return 'Rechazado permanentemente';
    }
  }

  void _mostrarSnack(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  DateTime? _parsearFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  Future<void> _buscarCita() async {
    final errRut = Validators.validateRut(_rutCtrl.text);
    if (errRut != null) {
      _mostrarSnack(errRut, error: true);
      return;
    }

    final rutNormalizado = _authService.normalizarRut(_rutCtrl.text);
    setState(() => _guardando = true);

    try {
      // 1. El donante se identifica por RUT; ahí está su uid y fecha de nacimiento
      final docDonante =
          await _firestore.collection('donantes').doc(rutNormalizado).get();
      if (!docDonante.exists) {
        setState(() {
          _citaActual = null;
          _fechaNacimientoDonante = widget.fechaNacimientoDonante;
        });
        _mostrarSnack(
          'No hay un donante registrado con el RUT $rutNormalizado.',
          error: true,
        );
        return;
      }

      final datosDonante = docDonante.data()!;
      final uid = datosDonante['uid'] as String?;
      final fechaNac = _parsearFecha(datosDonante['fechaNacimiento']) ??
          widget.fechaNacimientoDonante;

      // 2. Las citas se guardan con el uid del donante
      Cita? citaSeleccionada;
      if (uid != null) {
        final query = await _firestore
            .collection('citas')
            .where('uid', isEqualTo: uid)
            .get();

        if (query.docs.isNotEmpty) {
          final citas = query.docs.map((doc) {
            final d = doc.data();
            return Cita(
              id: doc.id,
              donanteId: rutNormalizado,
              sedeId: d['sedeId'] as String? ?? '',
              bloqueId: d['bloqueId'] as String? ?? '',
              fechaReserva: '${d['fecha'] ?? ''} ${d['horaInicio'] ?? ''}'.trim(),
              estado: d['estado'] as String? ?? Cita.estadoActiva,
            );
          }).toList();

          citaSeleccionada = citas.firstWhere(
            (c) => c.estado == Cita.estadoActiva,
            orElse: () => citas.last,
          );
        }
      }

      setState(() {
        _citaActual = citaSeleccionada;
        _fechaNacimientoDonante = fechaNac;
      });

      if (citaSeleccionada == null) {
        _mostrarSnack(
          'No se encontró cita registrada para el RUT $rutNormalizado.',
          error: true,
        );
      } else {
        _mostrarSnack(
          'Cita encontrada (${citaSeleccionada.fechaReserva}) - Estado: ${citaSeleccionada.estado}',
        );
      }
    } catch (e) {
      _mostrarSnack('Error al buscar cita: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _marcarAsistencia(EstadoCita nuevoEstado) async {
    final errRut = Validators.validateRut(_rutCtrl.text);
    if (errRut != null) {
      _mostrarSnack(
        'Ingresa un RUT válido para registrar asistencia.',
        error: true,
      );
      return;
    }

    if (_citaActual == null) {
      _mostrarSnack(
        'Primero busca una cita válida para el donante.',
        error: true,
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await _evaluacionService.registrarAsistencia(_citaActual!.id, nuevoEstado);
      setState(() {
        _citaActual = Cita(
          id: _citaActual!.id,
          donanteId: _citaActual!.donanteId,
          sedeId: _citaActual!.sedeId,
          bloqueId: _citaActual!.bloqueId,
          fechaReserva: _citaActual!.fechaReserva,
          estado: nuevoEstado.name,
        );
      });
      _mostrarSnack(
        nuevoEstado == EstadoCita.realizada
            ? 'Asistencia marcada como Realizada.'
            : 'Asistencia marcada como No Asistió.',
        error: nuevoEstado == EstadoCita.noAsistio,
      );
    } on EvaluacionException catch (e) {
      _mostrarSnack(e.message, error: true);
    } catch (e) {
      _mostrarSnack('Error al actualizar asistencia: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _elegirFechaHabilitacion() async {
    final manana = DateTime.now().add(const Duration(days: 1));
    final firstDate = DateTime(manana.year, manana.month, manana.day);
    final initialDate =
        (_fechaHabilitacion != null && !_fechaHabilitacion!.isBefore(firstDate))
            ? _fechaHabilitacion!
            : firstDate;

    final elegida = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(firstDate.year + 5),
    );
    if (elegida == null) return;

    setState(() {
      _fechaHabilitacion = elegida;
      _fechaHabCtrl.text =
          '${elegida.day.toString().padLeft(2, '0')}-${elegida.month.toString().padLeft(2, '0')}-${elegida.year}';
    });
  }

  Future<void> _guardarEvaluacion() async {
    final valido = _formKey.currentState!.validate();
    if (!valido) {
      _mostrarSnack('Revisa los campos marcados.', error: true);
      return;
    }

    if (_citaActual == null) {
      _mostrarSnack(
        'Busca y selecciona una cita antes de guardar.',
        error: true,
      );
      return;
    }

    if (_tipoSangre == null) {
      _mostrarSnack('Selecciona el tipo de sangre.', error: true);
      return;
    }

    if (_resultado == null) {
      _mostrarSnack('Selecciona el dictamen clínico.', error: true);
      return;
    }

    if (_fechaNacimientoDonante == null) {
      _mostrarSnack(
        'No se pudo determinar la fecha de nacimiento del donante.',
        error: true,
      );
      return;
    }

    final peso = double.tryParse(_pesoCtrl.text.trim().replaceAll(',', '.'));
    if (peso == null) {
      _mostrarSnack('Ingresa un peso numérico válido.', error: true);
      return;
    }

    final profesionalId =
        FirebaseAuth.instance.currentUser?.uid ?? 'profesional_sin_sesion';

    setState(() => _guardando = true);
    try {
      await _evaluacionService.registrarEvaluacion(
        cita: _citaActual!,
        fechaNacimientoDonante: _fechaNacimientoDonante!,
        pesoKg: peso,
        tipoSangre: _tipoSangre!,
        autorizacionParental: _autorizacionParental,
        resultado: _resultado!,
        fechaHabilitacion: _fechaHabilitacion,
        profesionalId: profesionalId,
      );

      _mostrarSnack('Evaluación registrada correctamente.');
    } on EvaluacionException catch (e) {
      _mostrarSnack(e.message, error: true);
    } catch (e) {
      _mostrarSnack('Error al guardar evaluación: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _irALogin() {
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final mostrarAutorizacion = _fechaNacimientoDonante != null &&
        EvaluacionValidators.requiereAutorizacionParental(
          _fechaNacimientoDonante!,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluación clínica - HemoCheck'),
        actions: [
          IconButton(
            tooltip: 'Ir a Login',
            onPressed: _irALogin,
            icon: const Icon(Icons.login),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irALogin,
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Login'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '1. Búsqueda y asistencia',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rutCtrl,
                      decoration: const InputDecoration(
                        labelText: 'RUT del donante',
                        hintText: '12.345.678-5',
                        border: OutlineInputBorder(),
                      ),
                      validator: Validators.validateRut,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _buscarCita,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ),
                ],
              ),
              if (_citaActual != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Cita: ${_citaActual!.id} · Fecha: ${_citaActual!.fechaReserva} · Estado: ${_citaActual!.estado}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guardando
                          ? null
                          : () => _marcarAsistencia(EstadoCita.realizada),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Marcar Realizada'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guardando
                          ? null
                          : () => _marcarAsistencia(EstadoCita.noAsistio),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('No Asistió'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(
                '2. Datos biométricos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pesoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  hintText: 'Ej: 65.0',
                  border: OutlineInputBorder(),
                ),
                validator: EvaluacionValidators.validatePeso,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TipoSangre>(
                initialValue: _tipoSangre,
                decoration: const InputDecoration(
                  labelText: 'Tipo de sangre',
                  border: OutlineInputBorder(),
                ),
                items: TipoSangre.values
                    .map(
                      (tipo) => DropdownMenuItem<TipoSangre>(
                        value: tipo,
                        child: Text(_etiquetaTipoSangre(tipo)),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _tipoSangre = val),
              ),
              if (mostrarAutorizacion) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _autorizacionParental,
                  onChanged: (val) =>
                      setState(() => _autorizacionParental = val ?? false),
                  title: const Text('Autorización parental presencial confirmada'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const Divider(height: 32),
              Text(
                '3. Dictamen clínico',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ResultadoEvaluacion>(
                groupValue: _resultado,
                onChanged: (val) {
                  setState(() {
                    _resultado = val;
                    if (val != ResultadoEvaluacion.diferidoTemporal) {
                      _fechaHabilitacion = null;
                      _fechaHabCtrl.clear();
                    }
                  });
                },
                child: Column(
                  children: ResultadoEvaluacion.values
                      .map(
                        (opcion) => RadioListTile<ResultadoEvaluacion>(
                          title: Text(_etiquetaResultado(opcion)),
                          value: opcion,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_resultado == ResultadoEvaluacion.diferidoTemporal) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fechaHabCtrl,
                  readOnly: true,
                  onTap: _elegirFechaHabilitacion,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de habilitación',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (_) => EvaluacionValidators.validateFechaHabilitacion(
                    _resultado!,
                    _fechaHabilitacion,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardarEvaluacion,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(_guardando ? 'Guardando...' : 'Guardar Evaluación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
