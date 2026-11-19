import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/airplane_network_gate.dart';
import 'harness/harness_sanity_test.dart' as harness_sanity;
import 'tiers/tier1_feature_coverage_test.dart' as tier1;
import 'tiers/tier2_boundary_corner_test.dart' as tier2;
import 'tiers/tier3_cross_feature_test.dart' as tier3;
import 'tiers/tier4_real_world_scenarios_test.dart' as tier4;

/// ============================================================================
/// Field Assistant 10/10 Master E2E Test Suite Aggregator
///
/// Milestone: E2E-M5
/// Methodology: 4-Tier Opaque-Box & Requirement-Driven Architecture
/// Pass Criteria: 200 Total Test Cases (100% Passing, Exit Code 0, Zero Leaks)
///
/// Tiers Executed:
/// - E2E-M1: Test Harness & Shared Fixtures Sanity (16 Tests)
/// - E2E-M2: Tier 1 Feature Coverage (Category-Partition F1–F16, 80 Tests)
/// - E2E-M3: Tier 2 Boundary & Corner Cases (BVA F1–F16, 80 Tests)
/// - E2E-M4: Tier 3 Cross-Feature Combinations (Pairwise, 16 Tests)
/// - E2E-M4: Tier 4 Amazonian Field Ministry Real-World Scenarios (8 Tests)
/// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AirplaneNetworkGate masterNetworkGate;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    masterNetworkGate = AirplaneNetworkGate(airplaneModeActive: true)
      ..install();
  });

  tearDownAll(() {
    masterNetworkGate.uninstall();
  });

  group('Field Assistant 10/10 Master E2E Test Suite', () {
    group(
      'Harness Sanity: Test Infrastructure & Fixtures Verification (16 Tests)',
      () {
        harness_sanity.main();
      },
    );

    group(
      'Tier 1: Feature Coverage (Category-Partition F1 to F16, 80 Tests)',
      () {
        tier1.main();
      },
    );

    group('Tier 2: Boundary & Corner Cases (BVA F1 to F16, 80 Tests)', () {
      tier2.main();
    });

    group('Tier 3: Pairwise Cross-Feature Combinations (16 Tests)', () {
      tier3.main();
    });

    group(
      'Tier 4: Amazonian Field Ministry Real-World Scenarios (8 Tests)',
      () {
        tier4.main();
      },
    );
  });
}
