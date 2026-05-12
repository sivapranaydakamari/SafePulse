/// Compile-time feature flags driven by --dart-define values.
///
/// Usage:
///   flutter run --dart-define=OBD_ENABLED=true --dart-define=COMMUNITY_REPORTS_ENABLED=true
///
/// All flags default to false so unfinished features are invisible in production
/// builds without explicit opt-in.
class FeatureFlags {
  FeatureFlags._();

  /// OBD-II vehicle speed integration (Phase 2 future scope).
  static const bool obdEnabled =
      bool.fromEnvironment('OBD_ENABLED', defaultValue: false);

  /// Community crowd-sourced hazard reporting (Phase 1 future scope).
  static const bool communityReportsEnabled =
      bool.fromEnvironment('COMMUNITY_REPORTS_ENABLED', defaultValue: false);

  /// Advanced AI crash model with retrain pipeline (Phase 2 future scope).
  static const bool advancedAiEnabled =
      bool.fromEnvironment('ADVANCED_AI_ENABLED', defaultValue: false);
}
