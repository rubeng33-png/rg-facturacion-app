import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import 'inicio.dart';

class PantallaAjustes extends StatefulWidget {
  final bool primeraVez;
  const PantallaAjustes({super.key, this.primeraVez = false});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  late final TextEditingController _url;
  late final TextEditingController _clave;
  late final TextEditingController _nombre;
  bool _verClave = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: App.ajustes.url);
    _clave = TextEditingController(text: App.ajustes.apiKey);
    _nombre = TextEditingController(text: App.ajustes.nombre);
  }

  @override
  void dispose() {
    _url.dispose();
    _clave.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Ajustes get _actuales => Ajustes(url: _url.text, apiKey: _clave.text, nombre: _nombre.text);

  Future<void> _probar() async {
    final a = _actuales;
    if (!a.completo) {
      avisar(context, 'Completá la dirección y la clave');
      return;
    }
    final salud = await conEspera(context, 'Probando conexión...', () => Api(a).salud());
    if (salud == null || !mounted) return;
    try {
      await Api(a).resumen();
    } catch (e) {
      if (mounted) await mostrarError(context, e);
      return;
    }
    if (!mounted) return;
    final ambiente = salud['ambiente'] == 'prod' ? 'Producción' : 'Pruebas';
    final envio = salud['envio_activo'] == true ? 'envío al SIFEN activo' : 'modo simulación';
    avisar(context, 'Conexión correcta: $ambiente, $envio');
  }

  Future<void> _guardar() async {
    final a = _actuales;
    if (!a.completo) {
      avisar(context, 'Completá la dirección y la clave');
      return;
    }
    App.ajustes = a;
    await a.guardar();
    if (!mounted) return;
    if (widget.primeraVez) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PantallaInicio()));
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.primeraVez ? 'Configurar conexión' : 'Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.primeraVez) ...[
            const Text('Bienvenido',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colores.texto)),
            const SizedBox(height: 6),
            const Text(
              'Conectá la app con tu servidor de facturación. Usá la dirección donde corre el '
              'backend (por ejemplo http://192.168.1.50:8000) y la api_key de su configuración.',
              style: TextStyle(color: Colores.textoSuave),
            ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Dirección del servidor',
              hintText: 'http://192.168.1.50:8000',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _clave,
            obscureText: !_verClave,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Clave de API',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _verClave = !_verClave),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Tu nombre (para el saludo)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _probar,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Probar conexión'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
