import 'package:flutter/material.dart';

import '../formato.dart';
import '../main.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import 'ajustes.dart';
import 'detalle.dart';
import 'documentos.dart';
import 'nuevo_documento.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  Map<String, dynamic>? _datos;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final d = await App.api.resumen();
      if (!mounted) return;
      setState(() {
        _datos = d;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    _cargar();
  }

  Future<void> _reintentar() async {
    final ok = await conEspera(context, 'Reenviando documentos...', () async {
      await App.api.reenviarPendientes();
      return true;
    });
    if (ok == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _encabezado(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _cuerpo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado() {
    final ahora = DateTime.now();
    final nombre = App.ajustes.nombre.isEmpty ? '' : ', ${App.ajustes.nombre}';
    final d = _datos;
    String chip = '...';
    if (d != null) {
      if (d['envio_activo'] != true) {
        chip = 'Simulación';
      } else {
        chip = d['ambiente'] == 'prod' ? 'Producción' : 'Pruebas';
      }
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colores.verdeOscuro,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 12, 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${saludo(ahora)}$nombre',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(fechaLarga(ahora),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(chip, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => _ir(const PantallaAjustes()),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _datos == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _datos == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colores.textoSuave),
            const SizedBox(height: 12),
            Text(_error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            TextButton(
                onPressed: () => _ir(const PantallaAjustes()),
                child: const Text('Revisar ajustes')),
          ],
        ),
      );
    }
    final d = _datos!;
    final hoy = Map<String, dynamic>.from(d['hoy'] as Map);
    final mes = Map<String, dynamic>.from(d['mes'] as Map);
    final ultimos = (d['ultimos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final pendientes = (d['pendientes_envio'] ?? 0) as num;
    final rechazados = (d['rechazados_sin_inutilizar'] ?? 0) as num;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: TarjetaDato(
              icono: Icons.bolt,
              titulo: 'Hoy',
              valor: gs(hoy['monto']),
              detalle: '${hoy['documentos']} documentos',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TarjetaDato(
              icono: Icons.description_outlined,
              titulo: 'Emitidos (mes)',
              valor: '${mes['emitidos']}',
              detalle: 'Este mes',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TarjetaDato(
              icono: Icons.trending_up,
              titulo: 'Facturado (mes)',
              valor: gsCompacto(mes['monto']),
              detalle: 'Acumulado del mes',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TarjetaDato(
              icono: Icons.verified_outlined,
              titulo: 'Aprobados',
              valor: '${mes['porcentaje_aprobados']}%',
              detalle: '${mes['aprobados']} de ${mes['emitidos']}',
            ),
          ),
        ]),
        if (pendientes > 0) ...[
          const SizedBox(height: 12),
          _aviso(
            color: const Color(0xFFE08A00),
            icono: Icons.schedule_send,
            texto: '$pendientes documento(s) sin enviar al SIFEN. Hay 72 horas para transmitirlos.',
            accion: 'Reenviar',
            onTap: _reintentar,
          ),
        ],
        if (rechazados > 0) ...[
          const SizedBox(height: 12),
          _aviso(
            color: const Color(0xFFD64545),
            icono: Icons.report_outlined,
            texto: '$rechazados documento(s) rechazado(s): hay que inutilizar esos números.',
            accion: 'Ver',
            onTap: () => _ir(const PantallaDocumentos(estadoInicial: 'RECHAZADO')),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => _ir(const PantallaNuevoDocumento()),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo documento'),
        ),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(
            child: Text('Últimos documentos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.texto)),
          ),
          TextButton(
            onPressed: () => _ir(const PantallaDocumentos()),
            child: const Text('Ver todos'),
          ),
        ]),
        const SizedBox(height: 6),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ultimos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Todavía no hay documentos emitidos.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colores.textoSuave)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < ultimos.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: Colores.borde),
                      FilaDocumento(
                        doc: ultimos[i],
                        onTap: () => _ir(PantallaDetalle(cdc: ultimos[i]['cdc'] as String)),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _aviso({
    required Color color,
    required IconData icono,
    required String texto,
    required String accion,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icono, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: TextStyle(color: color, fontSize: 13))),
        TextButton(onPressed: onTap, child: Text(accion)),
      ]),
    );
  }
}
