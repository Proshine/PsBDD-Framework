# Builds and runs the ConverterRefactor test projects (console runners).
#   .\build.ps1                    build and run both
#   .\build.ps1 -Project Unit      only ConverterTests (unit tests)
#   .\build.ps1 -Project Features  only ConverterFeatures (BDD scenarios)
#   .\build.ps1 -NoRun             build only
# Output: Tests\Build (exes), Tests\Build\dcu\Unit and \Features (dcus),
# Tests\BDDOutput (Markdown scenario documents).
# In the IDE, ConverterTests runs in TestInsight (its .dproj defines TESTINSIGHT).
param(
    [ValidateSet('All', 'Unit', 'Features')] [string]$Project = 'All',
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
$bds = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$lib = "$bds\lib\win32\release"
$tms = "$env:LOCALAPPDATA\TMS Setup\Products\tms.vcl.uipack\packages\d13\Win32\Release"
$spring = 'C:\Users\Public\Documents\Embarcadero\Libraries\spring4d\Library\Delphi13\Win32\Debug'

$projects = @()
if ($Project -in 'All', 'Unit') { $projects += @{ Name = 'ConverterTests'; Dcu = 'Unit' } }
if ($Project -in 'All', 'Features') { $projects += @{ Name = 'ConverterFeatures'; Dcu = 'Features' } }

Push-Location $PSScriptRoot
try {
    $failed = 0
    foreach ($p in $projects) {
        New-Item -ItemType Directory -Force "Build\dcu\$($p.Dcu)" | Out-Null
        & "$bds\bin\dcc32.exe" -B -Q '-NSSystem;Winapi;Vcl;Data;FireDAC' `
            "-U$lib;$tms;$spring" "-R$lib;$tms;$spring" "-NUBuild\dcu\$($p.Dcu)" '-EBuild' "$($p.Name).dpr"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        if (-not $NoRun) {
            & ".\Build\$($p.Name).exe"
            if ($LASTEXITCODE -ne 0) { $failed = $LASTEXITCODE }
        }
    }
    exit $failed
}
finally {
    Pop-Location
}
