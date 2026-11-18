<#
.SYNOPSIS
    Cross-platform E2E Test Runner for Field Assistant (FAES Master Engineering Program).

.DESCRIPTION
    Executes opaque-box end-to-end tests across Tiers 1 through 5, supporting tier isolation,
    code coverage collection, fail-fast behavior, and formatted summary reporting.

.PARAMETER Tier
    The test tier to execute: '1', '2', '3', '4', '5', or 'all' (default: 'all').
    - Tier 1: Category-Partition Feature Coverage (Happy Path)
    - Tier 2: Boundary Value Analysis & Fault Injection
    - Tier 3: Pairwise Cross-Feature Interactions
    - Tier 4: Real-World Field Ministry Journeys
    - Tier 5: Adversarial Hardening & Concurrency Stress
    - all: Full E2E Test Suite (Tiers 1-5 + Test Harness Validators)

.PARAMETER Coverage
    Enables lcov coverage collection into coverage/e2e_lcov.info.

.PARAMETER FailFast
    Halts execution immediately upon encountering the first test failure.

.PARAMETER Reporter
    Flutter test reporter type: 'expanded' (default), 'compact', or 'json'.

.PARAMETER Filter
    Optional plain name filter passed to 'flutter test --plain-name'.

.EXAMPLE
    .\tool\run_e2e_tests.ps1 -Tier all
    .\tool\run_e2e_tests.ps1 -Tier 1 -Reporter expanded
    .\tool\run_e2e_tests.ps1 -Tier 5 -Coverage
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("1", "2", "3", "4", "5", "all", "All", "ALL")]
    [string]$Tier = "all",

    [Alias("c")]
    [switch]$Coverage,

    [Alias("f")]
    [switch]$FailFast,

    [string]$Reporter = "expanded",

    [string]$Filter = ""
)

$ErrorActionPreference = "Continue"

$WorkspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $WorkspaceRoot

$TierNormalized = $Tier.ToLower()

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   FIELD ASSISTANT — E2E TEST RUNNER (FAES MASTER PROGRAM)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " Workspace: $WorkspaceRoot"
Write-Host " Target:    Tier '$TierNormalized'"
Write-Host " Coverage:  $(if ($Coverage) { 'ENABLED' } else { 'DISABLED' })"
Write-Host " Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
Write-Host "----------------------------------------------------------------------"

# Resolve test files for each tier
function Get-TierTestFiles {
    param ([string]$T)

    $files = [System.Collections.Generic.List[string]]::new()

    switch ($T) {
        "1" {
            $master = "test/e2e/faes_master/tier1_master_feature_coverage_test.dart"
            $std = "test/e2e/tier1_feature_coverage_test.dart"
            if (Test-Path "$WorkspaceRoot/$master") { $files.Add($master) }
            if (Test-Path "$WorkspaceRoot/$std") { $files.Add($std) }
        }
        "2" {
            $master = "test/e2e/faes_master/tier2_master_boundary_corner_test.dart"
            $std = "test/e2e/tier2_boundary_corner_test.dart"
            if (Test-Path "$WorkspaceRoot/$master") { $files.Add($master) }
            if (Test-Path "$WorkspaceRoot/$std") { $files.Add($std) }
        }
        "3" {
            $master = "test/e2e/faes_master/tier3_master_cross_feature_test.dart"
            $std = "test/e2e/tier3_cross_feature_test.dart"
            if (Test-Path "$WorkspaceRoot/$master") { $files.Add($master) }
            if (Test-Path "$WorkspaceRoot/$std") { $files.Add($std) }
        }
        "4" {
            $master = "test/e2e/faes_master/tier4_master_field_scenarios_test.dart"
            $std = "test/e2e/tier4_field_scenarios_test.dart"
            if (Test-Path "$WorkspaceRoot/$master") { $files.Add($master) }
            if (Test-Path "$WorkspaceRoot/$std") { $files.Add($std) }
        }
        "5" {
            $adv = "test/e2e/tier5_adversarial_hardening_test.dart"
            $stress = "test/e2e/helpers/empirical_stress_test.dart"
            if (Test-Path "$WorkspaceRoot/$adv") { $files.Add($adv) }
            if (Test-Path "$WorkspaceRoot/$stress") { $files.Add($stress) }
        }
        "all" {
            # Harness tests
            $h1 = "test/e2e/helpers/helpers_test.dart"
            $h2 = "test/e2e/helpers/widget_tester_test.dart"
            if (Test-Path "$WorkspaceRoot/$h1") { $files.Add($h1) }
            if (Test-Path "$WorkspaceRoot/$h2") { $files.Add($h2) }

            # Tiers 1-5
            foreach ($tNum in @("1", "2", "3", "4", "5")) {
                $tierFiles = Get-TierTestFiles -T $tNum
                foreach ($f in $tierFiles) {
                    if (-not $files.Contains($f)) { $files.Add($f) }
                }
            }

            # Master stabilization journey
            $stab = "test/e2e/stabilization_master_e2e_test.dart"
            if (Test-Path "$WorkspaceRoot/$stab" -and -not $files.Contains($stab)) {
                $files.Add($stab)
            }

            # Master aggregator suite if created
            $masterSuite = "test/e2e/master_e2e_suite_test.dart"
            if (Test-Path "$WorkspaceRoot/$masterSuite" -and -not $files.Contains($masterSuite)) {
                $files.Add($masterSuite)
            }
        }
    }

    return $files
}

$Targets = Get-TierTestFiles -T $TierNormalized

if ($Targets.Count -eq 0) {
    Write-Host "[ERROR] No test files found for Tier '$TierNormalized'." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($Targets.Count) test target(s) for execution:" -ForegroundColor Yellow
foreach ($t in $Targets) {
    Write-Host "  - $t"
}
Write-Host "----------------------------------------------------------------------"

$Results = [System.Collections.Generic.List[PSCustomObject]]::new()
$OverallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$AllPassed = $true

foreach ($target in $Targets) {
    Write-Host "`n>>> Running: $target" -ForegroundColor Cyan
    $testStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $cmdArgs = @("test", $target, "--reporter", $Reporter)
    if ($Coverage) {
        $cmdArgs += "--coverage"
    }
    if ($Filter) {
        $cmdArgs += @("--plain-name", $Filter)
    }

    & flutter @cmdArgs
    $exitCode = $LASTEXITCODE

    $testStopwatch.Stop()
    $durationSec = [Math]::Round($testStopwatch.Elapsed.TotalSeconds, 2)

    $status = if ($exitCode -eq 0) { "PASSED" } else { "FAILED" }
    if ($exitCode -ne 0) {
        $AllPassed = $false
    }

    $color = if ($exitCode -eq 0) { "Green" } else { "Red" }
    Write-Host "[$status] $target (${durationSec}s)" -ForegroundColor $color

    $Results.Add([PSCustomObject]@{
        Target   = $target
        Status   = $status
        Duration = "${durationSec}s"
        ExitCode = $exitCode
    })

    if ($exitCode -ne 0 -and $FailFast) {
        Write-Host "`n[FAIL-FAST] Halting execution due to failure in $target." -ForegroundColor Red
        break
    }
}

$OverallStopwatch.Stop()
$totalSec = [Math]::Round($OverallStopwatch.Elapsed.TotalSeconds, 2)

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "                  E2E TEST EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

foreach ($res in $Results) {
    $col = if ($res.Status -eq "PASSED") { "Green" } else { "Red" }
    $tag = if ($res.Status -eq "PASSED") { "[PASS]" } else { "[FAIL]" }
    Write-Host "$tag $($res.Target.PadRight(55)) $($res.Duration)" -ForegroundColor $col
}

Write-Host "----------------------------------------------------------------------"
$passedCount = ($Results | Where-Object { $_.Status -eq "PASSED" }).Count
$failedCount = ($Results | Where-Object { $_.Status -eq "FAILED" }).Count

Write-Host "Total Targets: $($Results.Count)"
Write-Host "Passed:        $passedCount" -ForegroundColor Green
Write-Host "Failed:        $failedCount" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })
Write-Host "Total Time:    ${totalSec}s"
Write-Host "======================================================================" -ForegroundColor Cyan

if ($AllPassed) {
    Write-Host ">>> E2E TEST STATUS: APPROVED (100% PASS, FAES 10/10)" -ForegroundColor Green
    exit 0
} else {
    Write-Host ">>> E2E TEST STATUS: REJECTED (FAILURES DETECTED)" -ForegroundColor Red
    exit 1
}
