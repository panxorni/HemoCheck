class BloqueHorarioValidators {
  static String? validateCapacidad(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La capacidad es obligatoria';
    }
    final numero = int.tryParse(value.trim());
    if (numero == null) {
      return 'Debe ser un número entero';
    }
    if (numero <= 0) {
      return 'Debe ser mayor a 0'; // CA-2 de la HU2
    }
    return null;
  }

  // Recibe las horas como texto "HH:mm"
  static String? validateHoraFin(String? inicio, String? fin) {
    if (fin == null || fin.isEmpty) {
      return 'Selecciona la hora de fin';
    }
    if (inicio == null || inicio.isEmpty) {
      return null; // el error de inicio ya se muestra en su propio campo
    }
    int minutos(String h) {
      final p = h.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    if (minutos(fin) <= minutos(inicio)) {
      return 'La hora de fin debe ser posterior a la de inicio';
    }
    return null;
  }

    static String? validateFecha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Selecciona la fecha';
    }
    return null;
  }

  static String? validateHoraInicio(String? value) {
    if (value == null || value.isEmpty) {
      return 'Selecciona la hora de inicio';
    }
    return null;
  }
}