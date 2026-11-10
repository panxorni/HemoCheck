import 'package:flutter/material.dart';
import 'package:hemocheck/utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Variables para guardar los datos del formulario (RF-01)
  String _rut = '';
  String _email = '';
  String _password = '';

  void _submitForm() {
    // Valida todos los TextFormFields vinculados a este formKey
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Si todo es válido (RUT, email, password), procede con el registro
      print("Registro exitoso con RUT: $_rut, Correo: $_email");
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
          child: SingleChildScrollView( // Evita el error de overflow cuando aparece el teclado
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'RUT',
                    hintText: 'Ej: 12345678-9',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  validator: Validators.validateRut, // Conecta lógica del RUT
                  onSaved: (value) => _rut = value!,
                ),
                SizedBox(height: 16),
                
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    hintText: 'ejemplo@correo.cl',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail, // Conecta lógica del email
                  onSaved: (value) => _email = value!,
                ),
                SizedBox(height: 16),
                
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Mínimo 6 caracteres, 1 mayúscula, 1 número',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true, // Oculta el texto para contraseñas
                  validator: Validators.validatePassword, // Conecta lógica de la contraseña
                  onSaved: (value) => _password = value!,
                ),
                SizedBox(height: 30),
                
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50), // Botón ancho para mejor UX
                  ),
                  child: Text('Crear Cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}