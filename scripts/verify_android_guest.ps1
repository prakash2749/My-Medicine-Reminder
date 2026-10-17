param(
    [Parameter(Mandatory = $true)][string]$ApkPath,
    [string]$Serial = 'emulator-5554',
    [string]$AdbPath = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
)
$ErrorActionPreference = 'Stop'
# Fresh-install fixture: removes only this app from the named disposable AVD.
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) { throw 'APK not found.' }
if ($Serial -notlike 'emulator-*') { throw 'This test requires an emulator.' }
$avdName = (& $AdbPath -s $Serial shell getprop ro.boot.qemu.avd_name).Trim()
if ($avdName -ne 'MedicineReminder_QA') { throw 'Expected the disposable MedicineReminder_QA AVD.' }
$previousAirplane = (& $AdbPath -s $Serial shell settings get global airplane_mode_on).Trim()
function Get-MedicineUi {
    & $AdbPath -s $Serial shell uiautomator dump /sdcard/medicine-epics-ui.xml | Out-Null
    [xml]((& $AdbPath -s $Serial shell cat /sdcard/medicine-epics-ui.xml) -join "`n")
}
function Tap-MedicineUi([string]$label) {
    $ui = Get-MedicineUi
    $node = @($ui.SelectNodes("//*[@text='$label' or @content-desc='$label']"))[-1]
    if ($null -eq $node) { throw "UI label missing: $label" }
    $coordinates = [regex]::Matches($node.bounds, '\d+') | ForEach-Object { [int]$_.Value }
    & $AdbPath -s $Serial shell input tap ([int](($coordinates[0] + $coordinates[2]) / 2)) ([int](($coordinates[1] + $coordinates[3]) / 2))
}
function Assert-MedicineGuest {
    $ui = Get-MedicineUi
    # Flutter merges the title/subtitle into one accessibility node.
    if (-not $ui.SelectSingleNode("//*[starts-with(@text,'Local guest') or starts-with(@content-desc,'Local guest')]")) {
        throw 'Guest Today screen missing.'
    }
}
try {
    & $AdbPath -s $Serial uninstall com.example.medicine_reminder | Out-Null
    & $AdbPath -s $Serial install $ApkPath
    if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
    & $AdbPath -s $Serial shell cmd connectivity airplane-mode enable
    & $AdbPath -s $Serial shell am start -W -n com.example.medicine_reminder/.MainActivity | Out-Null
    Start-Sleep -Seconds 5
    Tap-MedicineUi 'Continue as guest'
    Start-Sleep -Seconds 1
    Tap-MedicineUi 'Continue as guest'
    Start-Sleep -Seconds 3
    Assert-MedicineGuest
    'PASS: fresh normal app enters guest mode offline without Supabase configuration or notification permission.'
    & $AdbPath -s $Serial shell am force-stop com.example.medicine_reminder
    & $AdbPath -s $Serial shell am start -W -n com.example.medicine_reminder/.MainActivity | Out-Null
    Start-Sleep -Seconds 4
    Assert-MedicineGuest
    'PASS: normal app returns to the saved guest profile after restart.'
} finally {
    if ($previousAirplane -ne '1') { & $AdbPath -s $Serial shell cmd connectivity airplane-mode disable }
}
