import 'package:flutter/material.dart';
import 'package:hemocheck/services/auth_service.dart';

class DashboardDonanteScreen extends StatelessWidget {
  const DashboardDonanteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: const Center(child: Text('Bienvenido, donante')),
    );
  }
}