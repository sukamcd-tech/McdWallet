import 'package:flutter_test/flutter_test.dart';
import 'package:mcd_wallet/features/forex/domain/forex_rate_model.dart';

void main() {
  group('ForexRateModel Unit Tests', () {
    test('toJson and fromJson serialization/deserialization works correctly', () {
      const model = ForexRateModel(
        code: 'USD',
        name: 'Dolar Amerika',
        symbol: r'$',
        flag: '🇺🇸',
        rate: 16000.0,
        previousRate: 15800.0,
        trend: ForexTrend.up,
      );

      final json = model.toJson();
      final decoded = ForexRateModel.fromJson(json);

      expect(decoded.code, equals('USD'));
      expect(decoded.name, equals('Dolar Amerika'));
      expect(decoded.symbol, equals(r'$'));
      expect(decoded.flag, equals('🇺🇸'));
      expect(decoded.rate, equals(16000.0));
      expect(decoded.previousRate, equals(15800.0));
      expect(decoded.trend, equals(ForexTrend.up));
    });

    test('changePercent calculates correct percentage', () {
      const model = ForexRateModel(
        code: 'USD',
        name: 'Dolar Amerika',
        symbol: r'$',
        flag: '🇺🇸',
        rate: 16000.0,
        previousRate: 15000.0,
        trend: ForexTrend.up,
      );

      // (16000 - 15000) / 15000 * 100 = 6.6666%
      expect(model.changePercent, closeTo(6.6666, 0.001));
    });
  });
}
