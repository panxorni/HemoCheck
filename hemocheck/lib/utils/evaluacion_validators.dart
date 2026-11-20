import 'package:hemocheck/models/evaluacion.dart';

class EvaluacionValidators {

  // Revisa que el peso sea valido y alcance el minimo de 50 kg
  static String? validatePeso(String? value) {
    if (value == null || value.trim().isEmpty) return 'El peso es obligatorio';
    
    final peso = double.tryParse(value.trim().replaceAll(',', '.'));
    
    if (peso == null || !peso.isFinite) return 'Ingresa un peso válido';
    
    if (peso < 50.0) {
      return 'Bloqueo clínico: el peso mínimo para donar es 50 kg';
    }
    return null;
  }

  // Calcula la edad segun fecha de nacimiento y una fecha de referencia (por defecto, hoy)
  static int calcularEdad(DateTime nacimiento, {DateTime? hoy}) {
    
    final ref = hoy ?? DateTime.now();
    int edad = ref.year - nacimiento.year;
    
    if (ref.isBefore(DateTime(ref.year, nacimiento.month, nacimiento.day))) {
      edad--;
    }
    return edad;
  }

  // Devuelve true si tiene 17 años.
  static bool requiereAutorizacionParental(DateTime nacimiento, {DateTime? hoy}) {
    return calcularEdad(nacimiento, hoy: hoy) == 17;
  }

   // Valida que exista autorizacion confirmada si tiene 17 años
  static String? validateAutorizacionParental(DateTime nacimiento, bool confirmada, {DateTime? hoy}) {
    
    if (requiereAutorizacionParental(nacimiento, hoy: hoy) && !confirmada) {
      return 'Bloqueo clínico: donante de 17 años requiere autorización parental';
    }
    return null;
  }

  //Valida que la edad del donante sea igual o mayor a 17.
  static String? validateEdadMinima(DateTime nacimiento, {DateTime? hoy}) {
    
    if (calcularEdad(nacimiento, hoy: hoy) < 17){
      return 'Bloqueo clínico: la edad mínima para donar es 17 años';
    }
    return null;
  }

  // Alias de validateAutorizacionParental
  static String? validateAutorizacion(
    DateTime nacimiento, 
    bool confirmada, {
    DateTime? hoy,
  }) => validateAutorizacionParental(nacimiento, confirmada, hoy: hoy);

  // Si es diferido temporal, exige una fecha de habilitacion posterior a hoy
  static String? validateFechaHabilitacion(
    ResultadoEvaluacion resultado,
    DateTime? fechaHabilitacion, {
    DateTime? hoy,
  }) {
    
    if (resultado != ResultadoEvaluacion.diferidoTemporal) return null;
    
    if (fechaHabilitacion == null) {
      return 'La fecha de habilitación es obligatoria para donantes diferidos';
    }
    
    final ref = hoy ?? DateTime.now();
    final hoySinHora = DateTime(ref.year, ref.month, ref.day);
    final fechaSinHora = DateTime(
      fechaHabilitacion.year,
      fechaHabilitacion.month,
      fechaHabilitacion.day,
    );
    
    if (!fechaSinHora.isAfter(hoySinHora)) {
      return 'La fecha de habilitación debe ser posterior a hoy';
    }
    return null;
  }
}