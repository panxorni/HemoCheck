import 'package:flutter/material.dart';
import 'package:hemocheck/utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _rut = '';

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // si el RUT es valido, procede con el registro del donante
      print("Registro exitoso con RUT: $_rut");
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
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'RUT',
                  hintText: 'Ej: 12345678-9',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                validator: Validators.validateRut, // Conecta logica 
                onSaved: (value) => _rut = value!,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text('Crear Cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}