import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/dashboard/pioneer_pace_calculator.dart';

void main() {
  group('PioneerPaceCalculator Adversarial Challenge Suite', () {
    // ========================================================================
    // 1. Extreme Goals & Sub-Hour / Macro Boundary Tests
    // ========================================================================
    group('1. Extreme Goals (0h, 0.1h, 1000h, Negative)', () {
      test('Zero goal (0.0h) with zero completed hours', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 0.0,
          designatedWeekdays: [2, 4],
          completedHours: 0.0,
          currentDate: DateTime(2026, 10, 15),
        );

        expect(result.goalHours, equals(0.0));
        expect(result.completedHours, equals(0.0));
        expect(result.remainingHours, equals(0.0));
        expect(result.isGoalReached, isFalse,
            reason: 'Goal of 0h should not trigger goal reached celebration if goal is 0');
        expect(result.idealPacePerOuting, equals(Duration.zero));
        expect(result.idealPaceFormatted, equals('0h00m'));
        expect(
          result.formattedPaceText,
          startsWith('Faltam 0h em '),
        );
        expect(result.formattedPaceText.endsWith('por saída'), isTrue);
        expect(result.formattedPaceText.endsWith('.'), isFalse);
      });

      test('Zero goal (0.0h) with positive completed hours', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 0.0,
          designatedWeekdays: [6],
          completedHours: 15.0,
          currentDate: DateTime(2026, 10, 15),
        );

        expect(result.goalHours, equals(0.0));
        expect(result.completedHours, equals(15.0));
        expect(result.remainingHours, equals(0.0));
        expect(result.isGoalReached, isFalse);
        expect(result.idealPacePerOuting, equals(Duration.zero));
      });

      test('Negative goals (-50.0h, -0.001h) are clamped to 0.0h safely', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: -50.0,
          designatedWeekdays: [1, 3, 5],
          completedHours: 10.0,
          currentDate: DateTime(2026, 10, 15),
        );

        expect(result.goalHours, equals(0.0));
        expect(result.completedHours, equals(10.0));
        expect(result.remainingHours, equals(0.0));
        expect(result.isGoalReached, isFalse);
      });

      test('Sub-hour micro goal (0.1h = 6 minutes)', () {
        // Date with exactly 1 outing remaining
        // 2026-10-31 is Saturday (6)
        final resultSingleOuting = PioneerPaceCalculator.calculate(
          goalHours: 0.1,
          designatedWeekdays: [6],
          completedHours: 0.0,
          currentDate: DateTime(2026, 10, 31),
        );

        expect(resultSingleOuting.remainingHours, closeTo(0.1, 0.0001));
        expect(resultSingleOuting.remainingOutings, equals(1));
        expect(resultSingleOuting.idealPacePerOuting, equals(const Duration(minutes: 6)));
        expect(resultSingleOuting.idealPaceFormatted, equals('0h06m'));
        expect(
          resultSingleOuting.formattedPaceText,
          equals('Faltam 0.1h em 1 saídas. Seu ritmo ideal é de 0h06m por saída'),
        );
        expect(resultSingleOuting.formattedPaceText.endsWith('.'), isFalse);

        // Sub-hour goal across 3 outings: 0.1h = 6 min / 3 = 2 min per outing
        final resultThreeOutings = PioneerPaceCalculator.calculate(
          goalHours: 0.1,
          designatedWeekdays: [2, 4, 6],
          completedHours: 0.0,
          currentDate: DateTime(2026, 10, 25), // 27(Ter), 29(Qui), 31(Sab) = 3 saídas
        );
        expect(resultThreeOutings.remainingOutings, equals(3));
        expect(resultThreeOutings.idealPacePerOuting, equals(const Duration(minutes: 2)));
        expect(resultThreeOutings.idealPaceFormatted, equals('0h02m'));
        expect(
          resultThreeOutings.formattedPaceText,
          equals('Faltam 0.1h em 3 saídas. Seu ritmo ideal é de 0h02m por saída'),
        );
      });

      test('Macro pioneer goal (1000h) with 10 remaining outings', () {
        // 1000h in 10 outings = 100h per outing
        final result1000 = PioneerPaceCalculator.calculate(
          goalHours: 1000.0,
          designatedWeekdays: [1, 2, 3, 4, 5, 6, 7], // all 7 days from Oct 22 to 31 = 10 days
          completedHours: 0.0,
          currentDate: DateTime(2026, 10, 22),
        );
        expect(result1000.remainingOutings, equals(10));
        expect(result1000.remainingHours, equals(1000.0));
        expect(result1000.idealPacePerOuting, equals(const Duration(hours: 100)));
        expect(result1000.idealPaceFormatted, equals('100h00m'));
        expect(
          result1000.formattedPaceText,
          equals('Faltam 1000h em 10 saídas. Seu ritmo ideal é de 100h00m por saída'),
        );
      });
    });

    // ========================================================================
    // 2. Extreme Completed Hours (0h, 999.9h, Exact, Overachieved, Negative)
    // ========================================================================
    group('2. Extreme Completed Hours', () {
      test('Zero completed hours with standard 50h goal', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6], // 5 Saturdays in May 2026
          completedHours: 0.0,
          currentDate: DateTime(2026, 5, 2),
        );

        expect(result.completedHours, equals(0.0));
        expect(result.remainingHours, equals(50.0));
        expect(result.isGoalReached, isFalse);
        expect(result.remainingOutings, equals(5));
        expect(result.idealPacePerOuting, equals(const Duration(hours: 10)));
        expect(result.idealPaceFormatted, equals('10h00m'));
        expect(
          result.formattedPaceText,
          equals('Faltam 50h em 5 saídas. Seu ritmo ideal é de 10h00m por saída'),
        );
      });

      test('Extreme completed hours (999.9h) against 1000h goal', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 1000.0,
          designatedWeekdays: [6], // 2026-10-31 is Saturday -> 1 outing
          completedHours: 999.9,
          currentDate: DateTime(2026, 10, 31),
        );

        expect(result.remainingHours, closeTo(0.1, 0.0001));
        expect(result.isGoalReached, isFalse);
        expect(result.remainingOutings, equals(1));
        expect(result.idealPacePerOuting, equals(const Duration(minutes: 6)));
        expect(result.idealPaceFormatted, equals('0h06m'));
        expect(
          result.formattedPaceText,
          equals('Faltam 0.1h em 1 saídas. Seu ritmo ideal é de 0h06m por saída'),
        );
      });

      test('Exact completed hours (completed == goal) triggers celebration format', () {
        for (final goal in [0.5, 15.0, 30.0, 50.0, 70.0, 1000.0]) {
          final result = PioneerPaceCalculator.calculate(
            goalHours: goal,
            designatedWeekdays: [1, 2, 3, 4, 5, 6, 7],
            completedHours: goal,
            currentDate: DateTime(2026, 10, 15),
          );

          expect(result.isGoalReached, isTrue, reason: 'Failed for goal=$goal');
          expect(result.remainingHours, equals(0.0));
          expect(result.idealPacePerOuting, equals(Duration.zero));
          expect(result.idealPaceFormatted, equals('0h00m'));
          expect(
            result.formattedPaceText,
            equals('Meta atingida! Parabéns pelo empenho no ministério.'),
          );
        }
      });

      test('Overachieved goal (completed > goal) does not produce negative values', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4, 6],
          completedHours: 50.001,
          currentDate: DateTime(2026, 10, 15),
        );

        expect(result.isGoalReached, isTrue);
        expect(result.remainingHours, equals(0.0));
        expect(result.idealPacePerOuting, equals(Duration.zero));
        expect(
          result.formattedPaceText,
          equals('Meta atingida! Parabéns pelo empenho no ministério.'),
        );

        final hugeOverachievement = PioneerPaceCalculator.calculate(
          goalHours: 30.0,
          designatedWeekdays: [1, 2, 3, 4, 5, 6, 7],
          completedHours: 999.0,
          currentDate: DateTime(2026, 10, 1),
        );
        expect(hugeOverachievement.isGoalReached, isTrue);
        expect(hugeOverachievement.remainingHours, equals(0.0));
        expect(
          hugeOverachievement.formattedPaceText,
          equals('Meta atingida! Parabéns pelo empenho no ministério.'),
        );
      });

      test('Negative completed hours (-15.0h) clamped to 0.0h', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6],
          completedHours: -15.0,
          currentDate: DateTime(2026, 5, 2),
        );

        expect(result.completedHours, equals(0.0));
        expect(result.remainingHours, equals(50.0));
        expect(result.isGoalReached, isFalse);
      });
    });

    // ========================================================================
    // 3. Designated Weekdays Permutations & Edge Cases
    // ========================================================================
    group('3. Designated Weekdays Permutations (Zero, All 7, Duplicates, Invalid)', () {
      test('Zero designated weekdays ([]) returns 0 outings and falls back to remaining hours duration', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [],
          completedHours: 32.0,
          currentDate: DateTime(2026, 10, 15),
        );

        expect(result.remainingOutings, equals(0));
        expect(result.remainingHours, equals(18.0));
        expect(result.isGoalReached, isFalse);
        expect(result.idealPacePerOuting, equals(const Duration(hours: 18)));
        expect(result.idealPaceFormatted, equals('18h00m'));
        expect(
          result.formattedPaceText,
          equals('Faltam 18h em 0 saídas. Seu ritmo ideal é de 18h00m por saída'),
        );
        expect(result.formattedPaceText.endsWith('.'), isFalse);
      });

      test('All 7 weekdays ([1, 2, 3, 4, 5, 6, 7]) matches exact remaining days in month', () {
        // Oct 2026 has 31 days. From Oct 1: 31 days. From Oct 20: 12 days (20..31).
        final resultAllMonth = PioneerPaceCalculator.calculate(
          goalHours: 31.0,
          designatedWeekdays: [1, 2, 3, 4, 5, 6, 7],
          completedHours: 0.0,
          currentDate: DateTime(2026, 10, 1),
        );
        expect(resultAllMonth.remainingOutings, equals(31));
        expect(resultAllMonth.idealPacePerOuting, equals(const Duration(hours: 1)));
        expect(
          resultAllMonth.formattedPaceText,
          equals('Faltam 31h em 31 saídas. Seu ritmo ideal é de 1h00m por saída'),
        );

        final resultEndOfMonth = PioneerPaceCalculator.calculate(
          goalHours: 12.0,
          designatedWeekdays: [1, 2, 3, 4, 5, 6, 7],
          completedHours: 0.0,
          currentDate: DateTime(2026, 10, 20),
        );
        expect(resultEndOfMonth.remainingOutings, equals(12));
        expect(resultEndOfMonth.idealPacePerOuting, equals(const Duration(hours: 1)));
      });

      test('Duplicate weekdays in list do not inflate remainingOutings count', () {
        // Duplicate Tuesday (2), Thursday (4), Saturday (6)
        final withDuplicates = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 2, 2, 4, 4, 6, 6, 6, 6],
          completedHours: 32.0,
          currentDate: DateTime(2026, 10, 20),
        );

        final withoutDuplicates = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4, 6],
          completedHours: 32.0,
          currentDate: DateTime(2026, 10, 20),
        );

        expect(withDuplicates.remainingOutings, equals(withoutDuplicates.remainingOutings));
        expect(withDuplicates.idealPacePerOuting, equals(withoutDuplicates.idealPacePerOuting));
        expect(withDuplicates.formattedPaceText, equals(withoutDuplicates.formattedPaceText));
      });

      test('Unordered and mixed weekdays calculate identically to sorted weekdays', () {
        final reversed = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6, 4, 2],
          completedHours: 20.0,
          currentDate: DateTime(2026, 10, 10),
        );

        final sorted = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [2, 4, 6],
          completedHours: 20.0,
          currentDate: DateTime(2026, 10, 10),
        );

        expect(reversed.remainingOutings, equals(sorted.remainingOutings));
        expect(reversed.formattedPaceText, equals(sorted.formattedPaceText));
      });

      test('Invalid weekday integers outside [1..7] return 0 outings gracefully', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [-1, 0, 8, 99],
          completedHours: 20.0,
          currentDate: DateTime(2026, 10, 10),
        );

        expect(result.remainingOutings, equals(0));
        expect(result.remainingHours, equals(30.0));
      });
    });

    // ========================================================================
    // 4. Exhaustive Calendar Stress: Every Single Day of Every Month
    // ========================================================================
    group('4. Calendar Invariants Across Standard & Leap Years', () {
      final yearsToTest = [
        2024, // Leap year (366 days, Feb has 29)
        2026, // Standard year (365 days, Feb has 28)
        2028, // Leap year (366 days, Feb has 29)
        2000, // Century leap year (divisible by 400 -> Feb has 29)
        2100, // Century non-leap year (divisible by 100, not 400 -> Feb has 28)
      ];

      for (final year in yearsToTest) {
        test('Exhaustive day-by-day test for year $year', () {
          final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

          for (int month = 1; month <= 12; month++) {
            final expectedDaysInMonth = DateTime(year, month + 1, 0).day;

            if (month == 2) {
              expect(
                expectedDaysInMonth,
                equals(isLeapYear ? 29 : 28),
                reason: 'Feb $year must have ${isLeapYear ? 29 : 28} days',
              );
            }

            int? previousOutings;

            for (int day = 1; day <= expectedDaysInMonth; day++) {
              final date = DateTime(year, month, day);

              // 1. With all 7 weekdays: remainingOutings MUST equal remaining calendar days
              final resAll = PioneerPaceCalculator.calculate(
                goalHours: 50.0,
                designatedWeekdays: [1, 2, 3, 4, 5, 6, 7],
                completedHours: 10.0,
                currentDate: date,
              );
              final expectedRemainingDays = expectedDaysInMonth - day + 1;
              expect(
                resAll.remainingOutings,
                equals(expectedRemainingDays),
                reason: 'Failed on $year-$month-$day for all-weekdays',
              );

              // 2. Monotonicity check: remaining outings with fixed weekdays must be non-increasing
              final resFixed = PioneerPaceCalculator.calculate(
                goalHours: 50.0,
                designatedWeekdays: [2, 4, 6], // Ter, Qui, Sab
                completedHours: 10.0,
                currentDate: date,
              );

              if (previousOutings != null) {
                expect(
                  resFixed.remainingOutings <= previousOutings,
                  isTrue,
                  reason: 'Outings count must be monotonically non-increasing within month. Day $day had ${resFixed.remainingOutings} vs previous $previousOutings',
                );
              }
              previousOutings = resFixed.remainingOutings;

              // 3. String structure invariant check on every single day
              expect(resFixed.formattedPaceText.endsWith('.'), isFalse,
                  reason: 'Pace text must never end with a period: "${resFixed.formattedPaceText}" on $year-$month-$day');
              expect(
                resFixed.formattedPaceText,
                matches(RegExp(r'^Faltam \d+(\.\d+)?h em \d+ saídas\. Seu ritmo ideal é de \d+h\d{2}m por saída$')),
                reason: 'String format failed on $year-$month-$day: "${resFixed.formattedPaceText}"',
              );

              // 4. Invariant check on remaining hours and pace
              expect(resFixed.remainingHours >= 0.0, isTrue);
              expect(resFixed.idealPacePerOuting >= Duration.zero, isTrue);
            }
          }
        });
      }

      test('Explicit Leap Day Boundary Verification (Feb 29)', () {
        // 2024-02-29 is Thursday (weekday 4)
        final leap2024 = PioneerPaceCalculator.calculate(
          goalHours: 10.0,
          designatedWeekdays: [4],
          completedHours: 0.0,
          currentDate: DateTime(2024, 2, 29),
        );
        expect(leap2024.remainingOutings, equals(1));
        expect(leap2024.idealPacePerOuting, equals(const Duration(hours: 10)));
        expect(
          leap2024.formattedPaceText,
          equals('Faltam 10h em 1 saídas. Seu ritmo ideal é de 10h00m por saída'),
        );

        // 2028-02-29 is Tuesday (weekday 2)
        final leap2028 = PioneerPaceCalculator.calculate(
          goalHours: 10.0,
          designatedWeekdays: [2],
          completedHours: 0.0,
          currentDate: DateTime(2028, 2, 29),
        );
        expect(leap2028.remainingOutings, equals(1));

        // 2000-02-29 is Tuesday (weekday 2)
        final leap2000 = PioneerPaceCalculator.calculate(
          goalHours: 10.0,
          designatedWeekdays: [2],
          completedHours: 0.0,
          currentDate: DateTime(2000, 2, 29),
        );
        expect(leap2000.remainingOutings, equals(1));

        // 2100-02-28 is Sunday (weekday 7). Month ends on 28th.
        final nonLeap2100 = PioneerPaceCalculator.calculate(
          goalHours: 10.0,
          designatedWeekdays: [7],
          completedHours: 0.0,
          currentDate: DateTime(2100, 2, 28),
        );
        expect(nonLeap2100.remainingOutings, equals(1));
      });
    });

    // ========================================================================
    // 5. String Assertion & Decimal Formatting Rigor
    // ========================================================================
    group('5. Exact String Assertion Matching & Formatting Contract', () {
      test('No trailing period on standard, fractional, and zero outings messages', () {
        final cases = [
          PioneerPaceCalculator.calculate(
            goalHours: 50.0,
            designatedWeekdays: [6],
            completedHours: 32.0,
            currentDate: DateTime(2026, 5, 2),
          ),
          PioneerPaceCalculator.calculate(
            goalHours: 50.0,
            designatedWeekdays: [6],
            completedHours: 31.5,
            currentDate: DateTime(2026, 5, 2),
          ),
          PioneerPaceCalculator.calculate(
            goalHours: 50.0,
            designatedWeekdays: [],
            completedHours: 32.0,
            currentDate: DateTime(2026, 5, 2),
          ),
        ];

        for (final c in cases) {
          expect(c.formattedPaceText.endsWith('.'), isFalse);
          expect(c.formattedPaceText.endsWith('por saída'), isTrue);
        }
      });

      test('Exact match for milestone example: 50h, 32h completed, 5 outings', () {
        final result = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6],
          completedHours: 32.0,
          currentDate: DateTime(2026, 5, 2),
        );

        expect(
          result.formattedPaceText,
          equals('Faltam 18h em 5 saídas. Seu ritmo ideal é de 3h36m por saída'),
        );
      });

      test('Integer vs Decimal hours string format', () {
        // Integer remaining: 18.0 -> "18h"
        final intRes = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6],
          completedHours: 32.0,
          currentDate: DateTime(2026, 5, 2),
        );
        expect(intRes.formattedPaceText, contains('Faltam 18h em '));

        // Decimal remaining: 18.5 -> "18.5h"
        final decRes = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6],
          completedHours: 31.5,
          currentDate: DateTime(2026, 5, 2),
        );
        expect(decRes.formattedPaceText, contains('Faltam 18.5h em '));

        // Quarter hour remaining: 18.25 -> "18.3h" (one decimal place)
        final fracRes = PioneerPaceCalculator.calculate(
          goalHours: 50.0,
          designatedWeekdays: [6],
          completedHours: 31.75,
          currentDate: DateTime(2026, 5, 2),
        );
        expect(fracRes.formattedPaceText, contains('Faltam 18.3h em '));
      });

      test('Leading zeroes in minutes for idealPaceFormatted (e.g. 2h05m)', () {
        // 2h + 5min = 125 min = 2.08333h in 1 outing
        final result = PioneerPaceCalculator.calculate(
          goalHours: 2.0833333333333335,
          designatedWeekdays: [6],
          completedHours: 0.0,
          currentDate: DateTime(2026, 10, 31),
        );

        expect(result.idealPacePerOuting, equals(const Duration(hours: 2, minutes: 5)));
        expect(result.idealPaceFormatted, equals('2h05m'));
        expect(result.formattedPaceText, contains('de 2h05m por saída'));
      });
    });

    // ========================================================================
    // 6. High Throughput Stress Benchmark (10,000 Calculations)
    // ========================================================================
    group('6. High Throughput Calculation Stress', () {
      test('Executes 10,000 calculations at extreme throughput without memory leaks or degradation', () {
        // Warm-up JIT
        for (int i = 0; i < 500; i++) {
          PioneerPaceCalculator.calculate(
            goalHours: 50.0,
            designatedWeekdays: [2, 4, 6],
            completedHours: (i % 50).toDouble(),
            currentDate: DateTime(2026, 10, 1 + (i % 25)),
          );
        }

        int checksum = 0;
        final stopwatch = Stopwatch()..start();

        const int iterations = 10000;
        for (int i = 0; i < iterations; i++) {
          final day = 1 + (i % 28);
          final month = 1 + (i % 12);
          final year = 2024 + (i % 5);
          final goal = (30 + (i % 50)).toDouble();
          final completed = (i % 60).toDouble();
          final weekdays = [1 + (i % 7), 1 + ((i + 2) % 7)];

          final result = PioneerPaceCalculator.calculate(
            goalHours: goal,
            designatedWeekdays: weekdays,
            completedHours: completed,
            currentDate: DateTime.utc(year, month, day),
          );

          checksum += result.remainingOutings;
        }

        stopwatch.stop();

        final elapsedMs = stopwatch.elapsedMilliseconds;
        expect(checksum, greaterThan(0));
        // Requirement: 10,000 calculations executed within 100ms budget.
        expect(elapsedMs, lessThan(100),
            reason: 'High throughput failure: 10,000 calculations took ${elapsedMs}ms, exceeding 100ms budget');
      });
    });
  });
}
