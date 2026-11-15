# RG Facturación (app Android)

App Flutter para emitir y consultar facturas electrónicas a través del backend
`sifen-backend`. La app no firma ni habla con el SIFEN: todo eso lo hace el servidor.

## Pantallas

- **Inicio:** saludo, ambiente (Simulación / Pruebas / Producción), facturado hoy, emitidos y
  facturado del mes, % aprobados, avisos de pendientes y rechazados, y los últimos documentos.
- **Nuevo documento:** cliente sin nombre, con RUC (calcula y valida el DV y busca la razón social
  en el SIFEN) o con C.I. Servicio, mercadería o mixto; contado (medio de pago) o crédito (plazo);
  ítems con IVA 10 %, 5 % o exento y descuento.
- **Documentos:** listado con filtros por estado.
- **Detalle:** estado y respuesta del SIFEN, CDC (tocás y se copia), ítems, ver o imprimir el
  KuDE, compartir el PDF por WhatsApp o correo, nota de crédito precargada, cancelación y reintento.
- **Ajustes:** dirección del servidor, clave de API y tu nombre.

## Compilar con GitHub Actions

1. Creá un repo (por ejemplo `RG-Facturacion`) y subí esta carpeta tal cual, incluida `.github/`.
2. Cada push a `main` compila. También podés lanzarlo a mano en **Actions → Compilar APK → Run workflow**.
3. Descargá el APK desde el artefacto `rg-facturacion-apk` de la ejecución.

El workflow genera la carpeta `android/` con `flutter create` y agrega el permiso de internet y el
tráfico HTTP para la red local. Si más adelante querés cambiar el ícono o el paquete, generá
`android/` una vez, editala y subila al repo: el workflow la respeta.

## Conectar con el backend

En la PC o servidor donde está `sifen-backend`:

```bash
HOST=0.0.0.0 python app.py            # Windows (PowerShell): $env:HOST="0.0.0.0"; python app.py
```

En la app, en **Ajustes**: `http://IP-DE-LA-PC:8000` y la `api_key` de `config.json`.
El teléfono tiene que estar en la misma red. Para usarla desde afuera, publicá el backend con
HTTPS (Cloudflare Tunnel, un VPS, etc.) y usá esa dirección.
