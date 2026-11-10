class Validators {
  static String? validateRut(String? value) {
    if (value == null || value.isEmpty) {
      return 'El RUT es obligatorio'; 
    }

    // Limpiamos el string de puntos y guiones
    String rutLimpio = value.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();

    if (rutLimpio.length < 8) {
      return 'RUT inválido';
    }

    String rutSinDv = rutLimpio.substring(0, rutLimpio.length - 1);
    String dvIngresado = rutLimpio.substring(rutLimpio.length - 1);

    int rutNumerico;
    try {
      rutNumerico = int.parse(rutSinDv);
    } catch (e) {
      return 'RUT inválido';
    }

    // Algoritmo Módulo 11 para calcular el DV
    int m = 0, s = 1;
    for (; rutNumerico != 0; rutNumerico ~/= 10) {
      s = (s + rutNumerico % 10 * (9 - m++ % 6)) % 11;
    }
    String dvCalculado = s > 0 ? (s - 1).toString() : 'K';

    if (dvCalculado != dvIngresado) {
      return 'RUT inválido';
    }

    return null; // Es válido
  }
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo es obligatorio'; // RF-01, RF-09
    }
    
    // Regex estándar para validación de email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Correo inválido';
    }
    
    return null; // Es válido
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria'; // RF-01, RF-09
    }
    
    if (value.length < 6) {
      return 'Debe tener al menos 6 caracteres';
    }
    
    // Verifica si contiene al menos una letra mayúscula
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Debe incluir al menos una mayúscula';
    }
    
    // Verifica si contiene al menos un número
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Debe incluir al menos un número';
    }
    
    return null; // Es válido
  }
}
