import 'package:flutter/material.dart';
import 'package:hemocheck/services/auth_service.dart';
import 'package:hemocheck/utils/validators.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Variables para guardar las credenciales
  String _email = '';
  String _password = '';
  bool _cargando = false;

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _cargando = true);
    try {
      await AuthService().iniciarSesion(_email, _password);
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
      appBar: AppBar(title: Text('Iniciar Sesión - HemoCheck')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40), // Espaciado superior
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    hintText: 'ejemplo@correo.cl',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                  onSaved: (value) => _email = value!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Ingresa tu contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: Validators.validatePassword,
                  onSaved: (value) => _password = value!,
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _cargando ? null : _submitLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: _cargando
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Ingresar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/registro'),
                  child: Text('¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}