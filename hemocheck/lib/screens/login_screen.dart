import 'package:flutter/material.dart';
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

  void _submitLogin() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Si el formato es válido, aquí se llamaría al servicio de autenticación
      print("Inicio de sesión solicitado para: $_email");
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
                    prefixIcon: Icon(Icons.email), // Icono visual de apoyo
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail, // Reutiliza el validador ya testeado
                  onSaved: (value) => _email = value!,
                ),
                SizedBox(height: 16),
                
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Ingresa tu contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock), // Icono visual de apoyo
                  ),
                  obscureText: true, // Oculta el texto por seguridad
                  validator: Validators.validatePassword, // Asegura que cumpla los criterios mínimos
                  onSaved: (value) => _password = value!,
                ),
                SizedBox(height: 30),
                
                ElevatedButton(
                  onPressed: _submitLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text('Ingresar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}