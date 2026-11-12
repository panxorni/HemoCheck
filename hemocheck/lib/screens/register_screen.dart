import 'package:flutter/material.dart';
import 'package:hemocheck/services/auth_service.dart';
import 'package:hemocheck/utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const int _edadMinima = 17;
  static const int _edadMaxima = 70;

  final _formKey = GlobalKey<FormState>();
  final _fechaCtrl = TextEditingController();

  // Variables para guardar los datos del formulario (RF-01)
  String _rut = '';
  String _nombre = '';
  String _telefono = '';
  String _email = '';
  String _password = '';
  DateTime? _fechaNacimiento;
  bool _cargando = false;

  @override
  void dispose() {
    _fechaCtrl.dispose();
    super.dispose();
  }

  int _calcularEdad(DateTime nacimiento) {
    final hoy = DateTime.now();
    int edad = hoy.year - nacimiento.year;
    final cumpleEsteAno = DateTime(hoy.year, nacimiento.month, nacimiento.day);
    if (hoy.isBefore(cumpleEsteAno)) edad--;
    return edad;
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final masReciente =
        DateTime(ahora.year - _edadMinima, ahora.month, ahora.day);
    final masAntigua =
        DateTime(ahora.year - _edadMaxima - 1, ahora.month, ahora.day);
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime(ahora.year - 25, ahora.month, ahora.day),
      firstDate: masAntigua,
      lastDate: masReciente,
    );
    if (fecha != null) {
      setState(() {
        _fechaNacimiento = fecha;
        _fechaCtrl.text =
            '${fecha.day.toString().padLeft(2, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.year}';
      });
    }
  }

  Future<void> _submitForm() async {
    // Valida todos los TextFormFields vinculados a este formKey
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _cargando = true);
    try {
      await AuthService().registrar(
        rut: _rut,
        nombre: _nombre,
        fechaNacimiento: _fechaNacimiento!,
        telefono: _telefono,
        correo: _email,
        contrasena: _password,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, '/dashboard-donante', (r) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registro de Donante - HemoCheck')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'RUT',
                    hintText: 'Ej: 12345678-9',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  validator: Validators.validateRut,
                  onSaved: (value) => _rut = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                  onSaved: (value) => _nombre = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _fechaCtrl,
                  readOnly: true,
                  onTap: _elegirFecha,
                  decoration: InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (_) {
                    if (_fechaNacimiento == null) {
                      return 'La fecha de nacimiento es obligatoria';
                    }
                    final edad = _calcularEdad(_fechaNacimiento!);
                    if (edad < _edadMinima) {
                      return 'Debes tener al menos $_edadMinima años para donar';
                    }
                    if (edad > _edadMaxima) {
                      return 'La edad máxima para donar es $_edadMaxima años';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    hintText: 'Ej: +56912345678',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'Ingresa un teléfono válido'
                      : null,
                  onSaved: (value) => _telefono = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    hintText: 'ejemplo@correo.cl',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                  onSaved: (value) => _email = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Mínimo 6 caracteres, 1 mayúscula, 1 número',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: Validators.validatePassword,
                  onSaved: (value) => _password = value!,
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _cargando ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: _cargando
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Crear Cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}