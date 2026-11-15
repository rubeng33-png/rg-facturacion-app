import 'package:flutter_test/flutter_test.dart';
import 'package:rg_facturacion/formato.dart';

void main() {
  test('miles', () {
    expect(miles(920000), '920.000');
    expect(miles(1234567), '1.234.567');
    expect(miles(0), '0');
  });

  test('montos compactos', () {
    expect(gsCompacto(2600000), 'Gs. 2,6 M');
    expect(gs('630000'), 'Gs. 630.000');
  });

  test('DV del RUC igual que el backend', () {
    expect(calcularDv('80069563'), 1);
    expect(calcularDv('80012345'), 0);
    expect(calcularDv('3456789'), 5);
  });

  test('CDC agrupado', () {
    expect(cdcAgrupado('01444444017001001001452822017012515873260988'),
        '0144 4444 0170 0100 1001 4528 2201 7012 5158 7326 0988');
  });

  test('iniciales', () {
    expect(iniciales('Martín Giménez'), 'MG');
    expect(iniciales('Sin Nombre'), 'SN');
  });
}
