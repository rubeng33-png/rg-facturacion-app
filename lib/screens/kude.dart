import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../main.dart';

class PantallaKude extends StatefulWidget {
  final String cdc;
  final String nombre;
  const PantallaKude({super.key, required this.cdc, required this.nombre});

  @override
  State<PantallaKude> createState() => _PantallaKudeState();
}

class _PantallaKudeState extends State<PantallaKude> {
  late final Future<Uint8List> _pdf = App.api.kude(widget.cdc);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KuDE ${widget.nombre}')),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString(), textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bytes = snap.data!;
          return PdfPreview(
            build: (_) async => bytes,
            pdfFileName: '${widget.nombre}.pdf',
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
          );
        },
      ),
    );
  }
}
