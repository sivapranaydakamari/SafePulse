// Tests that every stub-gated feature is disabled by default (no --dart-define flags).
// These tests must pass in CI without any special environment setup.
import 'package:flutter_test/flutter_test.dart';
import 'package:safepulse/core/config/feature_flags.dart';

void main() {
  group('FeatureFlags — production defaults', () {
    test('OBD integration is disabled by default', () {
      expect(FeatureFlags.obdEnabled, isFalse,
          reason: 'OBD_ENABLED must default to false in production builds');
    });

    test('Community reports are disabled by default', () {
      expect(FeatureFlags.communityReportsEnabled, isFalse,
          reason: 'COMMUNITY_REPORTS_ENABLED must default to false in production builds');
    });

    test('Advanced AI model is disabled by default', () {
      expect(FeatureFlags.advancedAiEnabled, isFalse,
          reason: 'ADVANCED_AI_ENABLED must default to false in production builds');
    });

    test('isEnabled returns false for unknown feature', () {
      expect(FeatureFlags.isEnabled('nonexistent_feature'), isFalse);
    });

    test('isEnabled delegates to obdEnabled', () {
      expect(FeatureFlags.isEnabled('obd'), equals(FeatureFlags.obdEnabled));
    });

    test('isEnabled delegates to communityReportsEnabled', () {
      expect(
        FeatureFlags.isEnabled('community_reports'),
        equals(FeatureFlags.communityReportsEnabled),
      );
    });

    test('isEnabled delegates to advancedAiEnabled', () {
      expect(
        FeatureFlags.isEnabled('advanced_ai'),
        equals(FeatureFlags.advancedAiEnabled),
      );
    });
  });
}
