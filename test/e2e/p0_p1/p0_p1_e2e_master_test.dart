import 'package:flutter_test/flutter_test.dart';

import 'p0_tier1_feature_coverage_test.dart' as tier1;
import 'p0_tier2_boundary_corner_test.dart' as tier2;
import 'p0_tier3_cross_feature_test.dart' as tier3;
import 'p0_tier4_real_world_scenarios_test.dart' as tier4;

void main() {
  group('P0/P1 Dual Track E2E — Master Test Suite (Phases 1 to 6)', () {
    tier1.main();
    tier2.main();
    tier3.main();
    tier4.main();
  });
}
