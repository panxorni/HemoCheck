/// Clase utilitaria que agrupa las validaciones de entrada para el registro
/// de donaciones de sangre (RF-20, escenario alternativo 4' de CU-16).
class DonacionValidators {
  /// Límite superior permitido para el volumen de una extracción en mililitros.
  static const int volumenMaximoMl = 600;

  /// Valida que el volumen ingresado corresponda a un número entero positivo
  /// dentro del rango permitido (1 a [volumenMaximoMl] ml).
  ///
  /// Retorna un mensaje descriptivo si [value] es nulo, vacío, no entero,
  /// menor o igual a 0, o superior a [volumenMaximoMl]. Retorna `null` si
  /// el valor es válido.
  static String? validateVolumen(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El volumen es obligatorio';
    }

    final volumen = int.tryParse(value.trim());
    if (volumen == null) {
      return 'Debe ser un número entero';
    }

    if (volumen <= 0) {
      return 'El volumen debe ser mayor a 0 ml';
    }

    if (volumen > volumenMaximoMl) {
      return 'El volumen no puede superar los $volumenMaximoMl ml';
    }

    return null;
  }
}