import 'package:flutter/material.dart';

import '../formato.dart';
import '../main.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import 'detalle.dart';

class _Item {
  String codigo;
  String descripcion;
  double cantidad;
  double precio;
  double descuento;
  int iva;

  _Item({
    this.codigo = '',
    required this.descripcion,
    required this.cantidad,
    required this.precio,
    this.descuento = 0,
    this.iva = 10,
  });

  double get total => (precio - descuento) * cantidad;

  Map<String, dynamic> aJson() => {
        if (codigo.trim().isNotEmpty) 'codigo': codigo.trim(),
        'descripcion': descripcion.trim(),
        'cantidad': _limpio(cantidad),
        'precio_unitario': _limpio(precio),
        'descuento': _limpio(descuento),
        'iva': iva,
      };

  /// 250000.0 -> 250000 (entero) para que el JSON quede prolijo.
  static num _limpio(double v) => v == v.roundToDouble() ? v.round() : v;
}

const _motivosNc = {
  2: 'Devolución',
  1: 'Devolución y ajuste de precios',
  3: 'Descuento',
  4: 'Bonificación',
  5: 'Crédito incobrable',
  8: 'Ajuste de precio',
};

const _mediosPago = {
  1: 'Efectivo',
  5: 'Transferencia',
  4: 'Tarjeta de débito',
  3: 'Tarjeta de crédito',
  7: 'Billetera electrónica',
};

class PantallaNuevoDocumento extends StatefulWidget {
  /// Si viene una factura, la pantalla emite una nota de crédito sobre ella.
  final Map<String, dynamic>? facturaOriginal;
  const PantallaNuevoDocumento({super.key, this.facturaOriginal});

  @override
  State<PantallaNuevoDocumento> createState() => _PantallaNuevoDocumentoState();
}

class _PantallaNuevoDocumentoState extends State<PantallaNuevoDocumento> {
  int _tipoCliente = 0; // 0 consumidor final, 1 RUC, 2 cédula
  final _ruc = TextEditingController();
  final _cedula = TextEditingController();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _plazo = TextEditingController(text: '30 días');
  String _condicion = 'contado';
  int _medioPago = 1;
  int _tipoTransaccion = 2;
  int _motivoNc = 2;
  final List<_Item> _items = [];

  bool get _esNc => widget.facturaOriginal != null;

  @override
  void initState() {
    super.initState();
    final f = widget.facturaOriginal;
    if (f != null) {
      final c = Map<String, dynamic>.from((f['cliente_datos'] ?? {}) as Map);
      if (c['ruc'] != null) {
        _tipoCliente = 1;
        _ruc.text = '${c['ruc']}';
      } else if (c['documento'] != null) {
        _tipoCliente = 2;
        _cedula.text = '${c['documento']}';
      }
      if (_tipoCliente != 0) _nombre.text = '${c['nombre'] ?? ''}';
      _email.text = '${c['email'] ?? ''}';
      for (final e in (f['items'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(e as Map);
        _items.add(_Item(
          codigo: '${m['codigo'] ?? ''}',
          descripcion: '${m['descripcion']}',
          cantidad: numero(m['cantidad']),
          precio: numero(m['precio_unitario']),
          descuento: numero(m['descuento']),
          iva: (m['iva'] as num?)?.toInt() ?? 10,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_ruc, _cedula, _nombre, _email, _plazo]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _items.fold<double>(0, (s, i) => s + i.total);

  // ---------------------------------------------------------------- RUC
  String? _rucConDv() {
    final t = _ruc.text.trim().replaceAll('.', '').replaceAll(' ', '');
    if (t.isEmpty) return null;
    if (t.contains('-')) return t;
    return '$t-${calcularDv(t)}';
  }

  String? _errorRuc() {
    final t = _ruc.text.trim().replaceAll('.', '').replaceAll(' ', '');
    if (t.isEmpty || !t.contains('-')) return null;
    final partes = t.split('-');
    if (partes.length != 2 || int.tryParse(partes[1]) == null) return 'Formato: 80012345-6';
    final dv = calcularDv(partes[0]);
    return dv == int.parse(partes[1]) ? null : 'El DV correcto es $dv';
  }

  Future<void> _buscarRuc() async {
    final ruc = _rucConDv();
    if (ruc == null) return;
    final r = await conEspera(context, 'Consultando RUC...', () => App.api.consultarRuc(ruc));
    if (r == null || !mounted) return;
    final datos = Map<String, dynamic>.from((r['datos'] ?? {}) as Map);
    final razon = datos['dRazCons'];
    if (razon != null) {
      setState(() => _nombre.text = '$razon');
    } else {
      avisar(context, '${r['mensaje'] ?? 'RUC no encontrado'}');
    }
  }

  // -------------------------------------------------------------- ítems
  Future<void> _editarItem([int? indice]) async {
    final actual = indice == null ? null : _items[indice];
    final item = await showModalBottomSheet<_Item>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditorItem(item: actual),
    );
    if (item == null) return;
    setState(() {
      if (indice == null) {
        _items.add(item);
      } else {
        _items[indice] = item;
      }
    });
  }

  // -------------------------------------------------------------- emitir
  String? _validar() {
    if (_items.isEmpty) return 'Agregá al menos un ítem';
    if (_tipoCliente == 1) {
      if (_rucConDv() == null) return 'Ingresá el RUC del cliente';
      if (_errorRuc() != null) return _errorRuc();
      if (_nombre.text.trim().length < 4) return 'Ingresá la razón social del cliente';
    }
    if (_tipoCliente == 2) {
      if (_cedula.text.trim().isEmpty) return 'Ingresá la cédula del cliente';
      if (_nombre.text.trim().length < 4) return 'Ingresá el nombre del cliente';
    }
    if (_esNc && widget.facturaOriginal?['cdc'] == null) return 'Falta la factura asociada';
    return null;
  }

  Map<String, dynamic> _armar() {
    final cliente = <String, dynamic>{};
    if (_tipoCliente == 1) {
      cliente['ruc'] = _rucConDv();
      cliente['nombre'] = _nombre.text.trim();
    } else if (_tipoCliente == 2) {
      cliente['documento'] = _cedula.text.trim();
      cliente['tipo_documento'] = 1;
      cliente['nombre'] = _nombre.text.trim();
    }
    if (_email.text.trim().isNotEmpty) cliente['email'] = _email.text.trim();

    final doc = <String, dynamic>{
      'tipo': _esNc ? 5 : 1,
      'cliente': cliente,
      'items': _items.map((i) => i.aJson()).toList(),
    };
    if (_esNc) {
      doc['nota_credito'] = {'cdc_asociado': widget.facturaOriginal!['cdc'], 'motivo': _motivoNc};
    } else {
      doc['tipo_transaccion'] = _tipoTransaccion;
      doc['condicion'] = _condicion;
      if (_condicion == 'contado') {
        doc['pagos'] = [
          {'tipo': _medioPago}
        ];
      } else {
        doc['plazo'] = _plazo.text.trim().isEmpty ? '30 días' : _plazo.text.trim();
      }
    }
    return doc;
  }

  Future<void> _emitir() async {
    final error = _validar();
    if (error != null) {
      avisar(context, error);
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_esNc ? 'Emitir nota de crédito' : 'Emitir factura'),
        content: Text('Total: ${gs(_total)}\n'
            'Cliente: ${_tipoCliente == 0 ? 'Consumidor final' : _nombre.text.trim()}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Revisar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Emitir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final r = await conEspera(context, 'Firmando y enviando al SIFEN...', () => App.api.emitir(_armar()));
    if (r == null || !mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PantallaDetalle(cdc: r['cdc'] as String)));
  }

  // ---------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esNc ? 'Nota de crédito' : 'Nueva factura')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (_esNc) ...[
            _seccion('Factura asociada'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('N° ${widget.facturaOriginal!['numero']}'),
                subtitle: Text(gs(widget.facturaOriginal!['total'])),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _motivoNc,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: [
                for (final m in _motivosNc.entries)
                  DropdownMenuItem(value: m.key, child: Text(m.value)),
              ],
              onChanged: (v) => setState(() => _motivoNc = v ?? 2),
            ),
            const SizedBox(height: 8),
          ],
          _seccion('Cliente'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Sin nombre')),
              ButtonSegment(value: 1, label: Text('Con RUC')),
              ButtonSegment(value: 2, label: Text('Con C.I.')),
            ],
            selected: {_tipoCliente},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tipoCliente = s.first),
          ),
          const SizedBox(height: 12),
          if (_tipoCliente == 1) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _ruc,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'RUC',
                    hintText: '80012345-6',
                    errorText: _errorRuc(),
                    helperText: (_ruc.text.isNotEmpty && !_ruc.text.contains('-'))
                        ? 'DV calculado: ${_rucConDv()}'
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton.filledTonal(
                  tooltip: 'Buscar razón social en el SIFEN',
                  onPressed: _buscarRuc,
                  icon: const Icon(Icons.search),
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ],
          if (_tipoCliente == 2) ...[
            TextField(
              controller: _cedula,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cédula de identidad'),
            ),
            const SizedBox(height: 12),
          ],
          if (_tipoCliente != 0) ...[
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Nombre o razón social'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo (opcional)'),
          ),
          if (!_esNc) ...[
            _seccion('Operación'),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('Servicio')),
                ButtonSegment(value: 1, label: Text('Mercadería')),
                ButtonSegment(value: 3, label: Text('Mixto')),
              ],
              selected: {_tipoTransaccion},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _tipoTransaccion = s.first),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'contado', label: Text('Contado')),
                ButtonSegment(value: 'credito', label: Text('Crédito')),
              ],
              selected: {_condicion},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _condicion = s.first),
            ),
            const SizedBox(height: 12),
            if (_condicion == 'contado')
              DropdownButtonFormField<int>(
                initialValue: _medioPago,
                decoration: const InputDecoration(labelText: 'Medio de pago'),
                items: [
                  for (final m in _mediosPago.entries)
                    DropdownMenuItem(value: m.key, child: Text(m.value)),
                ],
                onChanged: (v) => setState(() => _medioPago = v ?? 1),
              )
            else
              TextField(
                controller: _plazo,
                decoration: const InputDecoration(labelText: 'Plazo', hintText: '30 días'),
              ),
          ],
          _seccion('Ítems'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Colores.borde),
                Dismissible(
                  key: ObjectKey(_items[i]),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: const Color(0xFFD64545),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => setState(() => _items.removeAt(i)),
                  child: ListTile(
                    onTap: () => _editarItem(i),
                    title: Text(_items[i].descripcion),
                    subtitle: Text('${cantidad(_items[i].cantidad)} × ${miles(_items[i].precio)}'
                        '${_items[i].descuento > 0 ? ' (desc. ${miles(_items[i].descuento)})' : ''}'
                        '  ·  ${_items[i].iva == 0 ? 'Exento' : 'IVA ${_items[i].iva}%'}'),
                    trailing: Text(miles(_items[i].total),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.add_circle_outline, color: Colores.verde),
                title: const Text('Agregar ítem',
                    style: TextStyle(color: Colores.verde, fontWeight: FontWeight.w600)),
                onTap: () => _editarItem(),
              ),
            ]),
          ),
          if (_items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Deslizá un ítem hacia la izquierda para quitarlo.',
                  style: TextStyle(fontSize: 12, color: Colores.textoSuave)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colores.borde)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total', style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
                  Text(gs(_total),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              child: FilledButton(
                onPressed: _emitir,
                child: Text(_esNc ? 'Emitir NC' : 'Emitir'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.texto)),
      );
}

class _EditorItem extends StatefulWidget {
  final _Item? item;
  const _EditorItem({this.item});

  @override
  State<_EditorItem> createState() => _EditorItemState();
}

class _EditorItemState extends State<_EditorItem> {
  late final TextEditingController _codigo;
  late final TextEditingController _descripcion;
  late final TextEditingController _cantidad;
  late final TextEditingController _precio;
  late final TextEditingController _descuento;
  late int _iva;
  String? _error;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _codigo = TextEditingController(text: it?.codigo ?? '');
    _descripcion = TextEditingController(text: it?.descripcion ?? '');
    _cantidad = TextEditingController(text: it == null ? '1' : _texto(it.cantidad));
    _precio = TextEditingController(text: it == null ? '' : _texto(it.precio));
    _descuento = TextEditingController(
        text: it == null || it.descuento == 0 ? '' : _texto(it.descuento));
    _iva = it?.iva ?? 10;
  }

  @override
  void dispose() {
    for (final c in [_codigo, _descripcion, _cantidad, _precio, _descuento]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _texto(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString().replaceAll('.', ',');

  /// Acepta "250.000", "250000" y "1,5"
  static double? _leer(String t) {
    t = t.trim();
    if (t.isEmpty) return null;
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', '');
    }
    return double.tryParse(t);
  }

  void _guardar() {
    final desc = _descripcion.text.trim();
    final cant = _leer(_cantidad.text);
    final precio = _leer(_precio.text);
    final descuento = _leer(_descuento.text) ?? 0;
    String? error;
    if (desc.isEmpty) {
      error = 'Escribí la descripción';
    } else if (cant == null || cant <= 0) {
      error = 'Cantidad inválida';
    } else if (precio == null || precio <= 0) {
      error = 'Precio inválido';
    } else if (descuento < 0 || descuento > precio) {
      error = 'El descuento no puede superar el precio';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      _Item(
        codigo: _codigo.text.trim(),
        descripcion: desc,
        cantidad: cant!,
        precio: precio!,
        descuento: descuento,
        iva: _iva,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.item == null ? 'Agregar ítem' : 'Editar ítem',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _descripcion,
              autofocus: widget.item == null,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _cantidad,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _precio,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Precio unitario', helperText: 'IVA incluido'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _descuento,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Descuento x unidad'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _codigo,
                  decoration: const InputDecoration(labelText: 'Código (opcional)'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            const Text('IVA', style: TextStyle(color: Colores.textoSuave)),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 10, label: Text('10%')),
                ButtonSegment(value: 5, label: Text('5%')),
                ButtonSegment(value: 0, label: Text('Exento')),
              ],
              selected: {_iva},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _iva = s.first),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFD64545))),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _guardar, child: const Text('Listo')),
          ],
        ),
      ),
    );
  }
}
