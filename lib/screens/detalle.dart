import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../formato.dart';
import '../main.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import 'kude.dart';
import 'nuevo_documento.dart';

class PantallaDetalle extends StatefulWidget {
  final String cdc;
  const PantallaDetalle({super.key, required this.cdc});

  @override
  State<PantallaDetalle> createState() => _PantallaDetalleState();
}

class _PantallaDetalleState extends State<PantallaDetalle> {
  Map<String, dynamic>? _doc;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final d = await App.api.detalle(widget.cdc);
      if (mounted) setState(() => _doc = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool get _valido {
    final e = _doc?['estado'];
    return e == 'APROBADO' || e == 'APROBADO_OBS' || e == 'SIMULADO';
  }

  Future<void> _compartir() async {
    final bytes = await conEspera(context, 'Preparando KuDE...', () => App.api.kude(widget.cdc));
    if (bytes == null) return;
    await Printing.sharePdf(bytes: bytes, filename: '${_doc?['numero'] ?? widget.cdc}.pdf');
  }

  Future<void> _cancelar() async {
    final motivo = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar documento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La factura se puede cancelar dentro de las 48 horas desde su aprobación '
              '(los demás documentos, dentro de 168 horas). Después corresponde una nota de crédito.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivo,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Motivo (mínimo 5 letras)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD64545), minimumSize: const Size(0, 44)),
            onPressed: () {
              if (motivo.text.trim().length >= 5) Navigator.pop(c, true);
            },
            child: const Text('Cancelar documento'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final r = await conEspera(
        context, 'Enviando cancelación...', () => App.api.cancelar(widget.cdc, motivo.text.trim()));
    if (r == null || !mounted) return;
    avisar(context, 'Cancelación: ${r['estado']} ${r['mensaje'] ?? ''}');
    _cargar();
  }

  Future<void> _notaCredito() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PantallaNuevoDocumento(facturaOriginal: _doc),
    ));
    _cargar();
  }

  Future<void> _reenviar() async {
    final ok = await conEspera(context, 'Reenviando...', () async {
      await App.api.reenviarPendientes();
      return true;
    });
    if (ok == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? 'Documento' : nombreTipo(d['tipo']))),
      body: d == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error.toString(), textAlign: TextAlign.center)),
            )
          : RefreshIndicator(onRefresh: _cargar, child: _contenido(d)),
    );
  }

  Widget _contenido(Map<String, dynamic> d) {
    final items = (d['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final cliente = Map<String, dynamic>.from((d['cliente_datos'] ?? {}) as Map);
    final idCliente = cliente['ruc'] != null
        ? 'RUC ${cliente['ruc']}'
        : (cliente['documento'] != null ? 'C.I. ${cliente['documento']}' : 'Consumidor final');
    final estado = d['estado']?.toString();
    final mensaje = d['mensaje']?.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('N° ${d['numero']}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  EtiquetaEstado(estado),
                ]),
                const SizedBox(height: 12),
                Text(gs(d['total']),
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: Colores.texto)),
                Text('IVA incluido: ${gs(d['total_iva'])}',
                    style: const TextStyle(color: Colores.textoSuave)),
                const Divider(height: 28),
                _dato('Cliente', '${d['cliente'] ?? ''}'),
                _dato('Identificación', idCliente),
                _dato('Emisión', fechaHora(d['fecha_emision']?.toString())),
                if (d['condicion'] != null) _dato('Condición', '${d['condicion']}'),
                if (d['fecha_aprobacion'] != null)
                  _dato('Aprobación', fechaHora(d['fecha_aprobacion']?.toString())),
                if (d['cdc_asociado'] != null)
                  _dato('Factura asociada', cdcAgrupado('${d['cdc_asociado']}')),
                const SizedBox(height: 6),
                const Text('CDC', style: TextStyle(fontSize: 12, color: Colores.textoSuave)),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.cdc));
                    avisar(context, 'CDC copiado');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(cdcAgrupado(widget.cdc),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (mensaje != null && mensaje.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: estadoInfo(estado).color.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: estadoInfo(estado).color),
                const SizedBox(width: 10),
                Expanded(child: Text('Respuesta del SIFEN: $mensaje')),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Ítems', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Colores.borde),
              ListTile(
                title: Text('${items[i]['descripcion']}'),
                subtitle: Text('${cantidad(items[i]['cantidad'])} × ${miles(numero(items[i]['precio_unitario']))}'
                    '  ·  ${items[i]['iva'] == 0 ? 'Exento' : 'IVA ${items[i]['iva']}%'}'),
                trailing: Text(miles(numero(items[i]['total'])),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PantallaKude(cdc: widget.cdc, nombre: '${d['numero']}'))),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Ver KuDE'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _compartir,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Compartir PDF'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (estado == 'PENDIENTE' || estado == 'GENERADO') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _reenviar,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Reintentar envío'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
        if (_valido && '${d['tipo']}' == '1') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _notaCredito,
            icon: const Icon(Icons.undo),
            label: const Text('Emitir nota de crédito'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
        if (_valido) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _cancelar,
            icon: const Icon(Icons.block, color: Color(0xFFD64545)),
            label: const Text('Cancelar documento', style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(etiqueta, style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
        ),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 13.5))),
      ]),
    );
  }
}
