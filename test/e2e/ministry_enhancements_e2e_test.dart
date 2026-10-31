import 'tier1_feature_coverage_test.dart' as tier1;
import 'tier2_boundary_corner_test.dart' as tier2;
import 'tier3_cross_feature_test.dart' as tier3;
import 'tier4_field_scenarios_test.dart' as tier4;

/// Master E2E Test Suite for Território (Ministry App)
/// Covering Requirements R1 through R5 across all 4 Tiers:
/// - Tier 1: Feature Coverage (25 test cases)
/// - Tier 2: Boundary & Corner Cases (26 test cases)
/// - Tier 3: Cross-Feature Combinations (5 integration flows)
/// - Tier 4: Real-World Field Ministry Scenarios (4 comprehensive scenarios)
///
/// Execution:
/// flutter test test/e2e/ministry_enhancements_e2e_test.dart
void main() {
  tier1.main();
  tier2.main();
  tier3.main();
  tier4.main();
}
