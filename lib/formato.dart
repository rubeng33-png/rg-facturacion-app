import 'package:flutter/material.dart';

double numero(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

/// 1234567 -> 1.234.567
String miles(num v) {
  final negativo = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${negativo ? '-' : ''}$b';
}

String gs(dynamic v) => 'Gs. ${miles(numero(v))}';

/// Gs. 2,6 M para montos grandes
String gsCompacto(dynamic v) {
  final n = numero(v);
  if (n.abs() >= 1000000) {
    return 'Gs. ${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  }
  return gs(n);
}

/// Cantidad: 2 o 1,5
String cantidad(dynamic v) {
  final n = numero(v);
  if (n == n.roundToDouble()) return miles(n);
  return n.toStringAsFixed(2).replaceAll('.', ',');
}

const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];

String fechaLarga(DateTime d) => '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

String saludo(DateTime d) {
  if (d.hour < 12) return 'Buenos días';
  if (d.hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

DateTime? fecha(String? iso) => iso == null ? null : DateTime.tryParse(iso);

String dosDigitos(int n) => n.toString().padLeft(2, '0');

String hora(String? iso) {
  final d = fecha(iso);
  return d == null ? '' : '${dosDigitos(d.hour)}:${dosDigitos(d.minute)}';
}

String fechaHora(String? iso) {
  final d = fecha(iso);
  if (d == null) return '';
  return '${dosDigitos(d.day)}/${dosDigitos(d.month)}/${d.year} ${dosDigitos(d.hour)}:${dosDigitos(d.minute)}';
}

/// Para listas: "18:28" si es hoy, "14/11 18:28" si no.
String cuando(String? iso) {
  final d = fecha(iso);
  if (d == null) return '';
  final h = DateTime.now();
  final mismoDia = d.year == h.year && d.month == h.month && d.day == h.day;
  return mismoDia ? hora(iso) : '${dosDigitos(d.day)}/${dosDigitos(d.month)} ${hora(iso)}';
}

String iniciales(String? nombre) {
  final partes = (nombre ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes[0].substring(0, partes[0].length >= 2 ? 2 : 1).toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}

String cdcAgrupado(String cdc) {
  final b = StringBuffer();
  for (var i = 0; i < cdc.length; i += 4) {
    if (i > 0) b.write(' ');
    b.write(cdc.substring(i, i + 4 > cdc.length ? cdc.length : i + 4));
  }
  return b.toString();
}

String nombreTipo(dynamic tipo) {
  switch ('$tipo') {
    case '1':
      return 'Factura Electrónica';
    case '5':
      return 'Nota de Crédito';
    case '6':
      return 'Nota de Débito';
    default:
      return 'Documento';
  }
}

/// Dígito verificador módulo 11 (igual que el backend), para validar RUC en el formulario.
int calcularDv(String numero) {
  final convertido = numero.split('').map((c) {
    final d = int.tryParse(c);
    return d != null ? c : c.toUpperCase().codeUnitAt(0).toString();
  }).join();
  var total = 0;
  var k = 2;
  for (var i = convertido.length - 1; i >= 0; i--) {
    if (k > 11) k = 2;
    total += int.parse(convertido[i]) * k;
    k++;
  }
  final resto = total % 11;
  return resto > 1 ? 11 - resto : 0;
}

class EstadoInfo {
  final String texto;
  final Color color;
  const EstadoInfo(this.texto, this.color);
}

EstadoInfo estadoInfo(String? estado) {
  switch (estado) {
    case 'APROBADO':
      return const EstadoInfo('Aprobado', Color(0xFF2E9E44));
    case 'APROBADO_OBS':
      return const EstadoInfo('Aprobado c/ obs.', Color(0xFF2A8C7A));
    case 'SIMULADO':
      return const EstadoInfo('Simulado', Color(0xFF5B7083));
    case 'PENDIENTE':
    case 'GENERADO':
      return const EstadoInfo('Pendiente', Color(0xFFE08A00));
    case 'RECHAZADO':
      return const EstadoInfo('Rechazado', Color(0xFFD64545));
    case 'CANCELADO':
      return const EstadoInfo('Cancelado', Color(0xFF8A8A8A));
    default:
      return EstadoInfo(estado ?? '-', const Color(0xFF8A8A8A));
  }
}
