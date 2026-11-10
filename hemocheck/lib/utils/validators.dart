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

  // luego se agregan validadores de email y conntraseña
}