import 'package:flutter/material.dart';

import '../formato.dart';
import '../tema.dart';

class EtiquetaEstado extends StatelessWidget {
  final String? estado;
  const EtiquetaEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final info = estadoInfo(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(info.texto,
          style: TextStyle(color: info.color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

class TarjetaDato extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final String detalle;

  const TarjetaDato({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colores.verde.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, size: 18, color: Colores.verde),
            ),
            const SizedBox(height: 10),
            Text(titulo, style: const TextStyle(fontSize: 12, color: Colores.textoSuave)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: Colores.texto)),
            ),
            const SizedBox(height: 2),
            Text(detalle, style: const TextStyle(fontSize: 11, color: Colores.textoSuave)),
          ],
        ),
      ),
    );
  }
}

class FilaDocumento extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onTap;

  const FilaDocumento({super.key, required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre = (doc['cliente_nombre'] ?? doc['cliente'] ?? '').toString();
    final esNc = '${doc['tipo']}' == '5';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFEDF1EB),
              child: Text(iniciales(nombre),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colores.textoSuave)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colores.texto)),
                  const SizedBox(height: 2),
                  Text('${cuando(doc['fecha_emision'])} · ${nombreTipo(doc['tipo'])}',
                      style: const TextStyle(fontSize: 12, color: Colores.textoSuave)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${esNc ? '-' : ''}${miles(numero(doc['total']))}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: esNc ? const Color(0xFFD64545) : Colores.texto)),
                const SizedBox(height: 3),
                EtiquetaEstado(doc['estado']?.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> mostrarError(BuildContext context, Object error) async {
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('No se pudo completar'),
      content: Text(error.toString()),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
    ),
  );
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}

/// Muestra un diálogo de espera mientras corre [tarea]; devuelve su resultado o null si falló.
Future<T?> conEspera<T>(BuildContext context, String texto, Future<T> Function() tarea) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 18),
          Expanded(child: Text(texto)),
        ]),
      ),
    ),
  );
  try {
    final r = await tarea();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return r;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await mostrarError(context, e);
    }
    return null;
  }
}
