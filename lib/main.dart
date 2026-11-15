import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/ajustes.dart';
import 'screens/inicio.dart';
import 'tema.dart';

/// Estado global simple: ajustes de conexión y cliente de la API.
class App {
  static Ajustes ajustes = Ajustes();
  static Api get api => Api(ajustes);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  App.ajustes = await Ajustes.cargar();
  runApp(const RgFacturacion());
}

class RgFacturacion extends StatelessWidget {
  const RgFacturacion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RG Facturación',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      home: App.ajustes.completo ? const PantallaInicio() : const PantallaAjustes(primeraVez: true),
    );
  }
}
