import 'package:flutter/material.dart';

import '../main.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import 'detalle.dart';

class PantallaDocumentos extends StatefulWidget {
  final String? estadoInicial;
  const PantallaDocumentos({super.key, this.estadoInicial});

  @override
  State<PantallaDocumentos> createState() => _PantallaDocumentosState();
}

class _PantallaDocumentosState extends State<PantallaDocumentos> {
  static const _filtros = <String?, String>{
    null: 'Todos',
    'APROBADO': 'Aprobados',
    'PENDIENTE': 'Pendientes',
    'RECHAZADO': 'Rechazados',
    'CANCELADO': 'Cancelados',
    'SIMULADO': 'Simulados',
  };
  static const _porPagina = 30;

  String? _estado;
  final List<Map<String, dynamic>> _docs = [];
  bool _cargando = false;
  bool _hayMas = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _estado = widget.estadoInicial;
    _recargar();
  }

  Future<void> _recargar() async {
    _docs.clear();
    _hayMas = true;
    await _cargarMas();
  }

  Future<void> _cargarMas() async {
    if (_cargando || !_hayMas) return;
    setState(() => _cargando = true);
    try {
      final nuevos = await App.api.documentos(
          estado: _estado, limite: _porPagina, offset: _docs.length);
      if (!mounted) return;
      setState(() {
        _docs.addAll(nuevos);
        _hayMas = nuevos.length == _porPagina;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final f in _filtros.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.value),
                      selected: _estado == f.key,
                      onSelected: (_) {
                        setState(() => _estado = f.key);
                        _recargar();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recargar,
              child: _lista(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_docs.isEmpty && _cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_docs.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Text(_error?.toString() ?? 'No hay documentos con este filtro.',
              textAlign: TextAlign.center, style: const TextStyle(color: Colores.textoSuave)),
        ),
      ]);
    }
    return ListView.separated(
      itemCount: _docs.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colores.borde),
      itemBuilder: (context, i) {
        if (i == _docs.length) {
          if (!_hayMas) return const SizedBox(height: 24);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton(onPressed: _cargarMas, child: const Text('Cargar más')),
          );
        }
        final d = _docs[i];
        return Container(
          color: Colors.white,
          child: FilaDocumento(
            doc: d,
            onTap: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PantallaDetalle(cdc: d['cdc'] as String)));
              _recargar();
            },
          ),
        );
      },
    );
  }
}
