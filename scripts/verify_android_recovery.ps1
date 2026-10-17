param(
    [string]$Adb = 'C:/Users/praka/AppData/Local/Android/Sdk/platform-tools/adb.exe',
    [string]$Device = 'emulator-5554',
    [string]$FixtureApk = 'build/recovery-system-fixture.apk'
)

$ErrorActionPreference = 'Stop'
if ($Device -notmatch '^emulator-\d+$') { throw 'Use a disposable emulator, never a personal phone.' }
if (-not (Test-Path -LiteralPath $FixtureApk)) { throw 'Build and seed recovery_system_fixture_test.dart first.' }
$medicineAvdName = & $Adb -s $Device emu avd name
if ($medicineAvdName[0] -ne 'MedicineReminder_QA') { throw 'This script is scoped to the isolated MedicineReminder_QA emulator.' }

function Invoke-MedicineAdb([string[]]$Arguments) {
    $medicineOutput = & $Adb -s $Device @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $medicineOutput" }
    return $medicineOutput
}

function Stop-MedicineProcess {
    Invoke-MedicineAdb -Arguments @('shell', 'input', 'keyevent', 'KEYCODE_HOME') | Out-Null
    $medicineProcessId = & $Adb -s $Device shell pidof com.example.medicine_reminder
    if ($LASTEXITCODE -eq 0 -and "$medicineProcessId".Trim() -match '^\d+$') {
        # Kill only the synthetic test app without putting its package in force-stop.
        Invoke-MedicineAdb -Arguments @('shell', 'run-as', 'com.example.medicine_reminder', 'kill', '-9', "$medicineProcessId".Trim()) | Out-Null
        Start-Sleep -Seconds 1
    }
    Invoke-MedicineAdb -Arguments @('logcat', '-c') | Out-Null
}

function Confirm-MedicineRecovery([string]$Phase) {
    $medicineSucceeded = $false
    for ($medicineAttempt = 0; $medicineAttempt -lt 45; $medicineAttempt++) {
        $medicineLog = Invoke-MedicineAdb -Arguments @('logcat', '-d', '-s', 'WM-WorkerWrapper', 'flutter', 'MedicineRecovery')
        if ($medicineLog -match 'Worker result SUCCESS.*medicine-system-recovery') { $medicineSucceeded = $true; break }
        if ($medicineLog -match 'Worker result FAILURE.*medicine-system-recovery') { throw "Cold recovery failed: $Phase" }
        Start-Sleep -Seconds 1
    }
    if (-not $medicineSucceeded) { throw "Cold recovery timed out: $Phase" }
    $medicineReason = Invoke-MedicineAdb -Arguments @('shell', 'run-as', 'com.example.medicine_reminder', 'cat', 'shared_prefs/medicine_recovery.xml')
    $medicineLog | Set-Content -LiteralPath "build/recovery-system-$Phase.log"
    $medicineReason | Add-Content -LiteralPath "build/recovery-system-$Phase.log"
    # A normal launch avoids the debug driver's start-paused race with headless isolates.
    # The fixture verifies native alarms/data BEFORE binding any foreground provider.
    Invoke-MedicineAdb -Arguments @('shell', 'am', 'start', '-n', 'com.example.medicine_reminder/.MainActivity', '-f', '0x10008000') | Out-Null
    $medicineVerified = $false
    for ($medicineAttempt = 0; $medicineAttempt -lt 30; $medicineAttempt++) {
        $medicineLog = Invoke-MedicineAdb -Arguments @('logcat', '-d', '-s', 'flutter', 'WM-WorkerWrapper')
        if ($medicineLog -match 'Some tests failed|TestFailure|EXCEPTION CAUGHT') { throw "Fixture assertions failed: $Phase" }
        if ($medicineLog -match 'All tests passed!') { $medicineVerified = $true; break }
        Start-Sleep -Seconds 1
    }
    $medicineLog | Add-Content -LiteralPath "build/recovery-system-$Phase.log"
    if (-not $medicineVerified) { throw "Fixture verification timed out: $Phase" }
    Write-Output "PASS $Phase - background recovery and unchanged confirmations/inventory"
}

$medicineOriginalZone = (Invoke-MedicineAdb -Arguments @('shell', 'getprop', 'persist.sys.timezone')).Trim()
$medicineOriginalAutoTime = (Invoke-MedicineAdb -Arguments @('shell', 'settings', 'get', 'global', 'auto_time')).Trim()
try {
    Stop-MedicineProcess
    $medicineTravelZone = if ($medicineOriginalZone -eq 'America/New_York') { 'Europe/London' } else { 'America/New_York' }
    Invoke-MedicineAdb -Arguments @('shell', 'cmd', 'alarm', 'set-timezone', $medicineTravelZone) | Out-Null
    Confirm-MedicineRecovery 'timezone'

    Stop-MedicineProcess
    Invoke-MedicineAdb -Arguments @('shell', 'settings', 'put', 'global', 'auto_time', '0') | Out-Null
    Start-Sleep -Seconds 2
    $medicineForwardTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 7200000
    Invoke-MedicineAdb -Arguments @('shell', 'cmd', 'alarm', 'set-time', "$medicineForwardTime") | Out-Null
    Confirm-MedicineRecovery 'clock-forward'

    Stop-MedicineProcess
    $medicineCurrentTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Invoke-MedicineAdb -Arguments @('shell', 'cmd', 'alarm', 'set-time', "$medicineCurrentTime") | Out-Null
    Confirm-MedicineRecovery 'clock-backward'

    Stop-MedicineProcess
    Invoke-MedicineAdb -Arguments @('install', '-r', '-t', $FixtureApk) | Out-Null
    Confirm-MedicineRecovery 'package-update'

    Stop-MedicineProcess
    Invoke-MedicineAdb -Arguments @('reboot') | Out-Null
    Invoke-MedicineAdb -Arguments @('wait-for-device') | Out-Null
    $medicineBooted = $false
    for ($medicineAttempt = 0; $medicineAttempt -lt 60; $medicineAttempt++) {
        $medicineBoot = & $Adb -s $Device shell getprop sys.boot_completed 2>$null
        if ("$medicineBoot".Trim() -eq '1') { $medicineBooted = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $medicineBooted) { throw 'Emulator reboot did not complete.' }
    Invoke-MedicineAdb -Arguments @('shell', 'input', 'keyevent', '82') | Out-Null
    Confirm-MedicineRecovery 'reboot'
}
finally {
    Invoke-MedicineAdb -Arguments @('shell', 'cmd', 'alarm', 'set-timezone', $medicineOriginalZone) | Out-Null
    $medicineCurrentTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Invoke-MedicineAdb -Arguments @('shell', 'cmd', 'alarm', 'set-time', "$medicineCurrentTime") | Out-Null
    Invoke-MedicineAdb -Arguments @('shell', 'settings', 'put', 'global', 'auto_time', $medicineOriginalAutoTime) | Out-Null
}
