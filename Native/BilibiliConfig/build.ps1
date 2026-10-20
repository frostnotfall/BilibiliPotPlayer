param([string]$OutputExe)
$ErrorActionPreference = 'Stop'
$nativeRoot = $PSScriptRoot
$repoRoot = [IO.Path]::GetFullPath((Join-Path $nativeRoot '..\..'))
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$installation) { throw 'Visual Studio C++ x64 build tools were not found.' }
$vcvars = Join-Path $installation 'VC\Auxiliary\Build\vcvarsall.bat'
$objectDir = Join-Path $nativeRoot 'build\x64'
$testDir = Join-Path $nativeRoot 'build\tests'
$outputDir = Join-Path $repoRoot 'Extension\Media\PlayParse'
New-Item -ItemType Directory -Force -Path $objectDir, $testDir | Out-Null
$exe = if ($OutputExe) { [IO.Path]::GetFullPath($OutputExe) } else { Join-Path $outputDir 'Bilibili_Config_Editor.exe' }
$common = '/nologo /std:c++17 /O2 /MT /EHsc /W4 /utf-8 /DUNICODE /D_UNICODE /D_CRT_SECURE_NO_WARNINGS'
$link = '/INCREMENTAL:NO /OPT:REF /OPT:ICF /DYNAMICBASE /NXCOMPAT'
$buildScript = @"
@echo off
chcp 65001 >nul
call "$vcvars" x64 >nul
if errorlevel 1 exit /b %errorlevel%
cl $common "$nativeRoot\main.cpp" "$nativeRoot\ConfigDocument.cpp" "$nativeRoot\Settings.cpp" "$nativeRoot\Preview.cpp" /Fe:"$exe" /link $link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED /MANIFESTINPUT:"$nativeRoot\editor.manifest" user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib msimg32.lib
if errorlevel 1 exit /b %errorlevel%
cl $common "$nativeRoot\tests.cpp" "$nativeRoot\ConfigDocument.cpp" "$nativeRoot\Settings.cpp" /Fe:"$objectDir\tests.exe" /link $link
if errorlevel 1 exit /b %errorlevel%
cl $common /DBILI_UI_TEST "$nativeRoot\main.cpp" "$nativeRoot\ConfigDocument.cpp" "$nativeRoot\Settings.cpp" "$nativeRoot\Preview.cpp" /Fe:"$objectDir\ui-tests.exe" /link $link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED /MANIFESTINPUT:"$nativeRoot\editor.manifest" user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib msimg32.lib
if errorlevel 1 exit /b %errorlevel%
dumpbin /nologo /dependents "$exe"
exit /b %errorlevel%
"@
$scriptPath = Join-Path $objectDir 'build.cmd'
[IO.File]::WriteAllText($scriptPath, $buildScript, [Text.UTF8Encoding]::new($false))
Push-Location -LiteralPath $objectDir
try {
    & $scriptPath
    if ($LASTEXITCODE -ne 0) { throw "Build failed ($LASTEXITCODE)." }
    & (Join-Path $objectDir 'tests.exe') (Join-Path $outputDir 'Bilibili_Config.json') $testDir
    if ($LASTEXITCODE -ne 0) { throw 'Configuration tests failed.' }
    $uiProcess = Start-Process -FilePath (Join-Path $objectDir 'ui-tests.exe') -ArgumentList ('"' + (Join-Path $testDir 'ui-fixture.json') + '"') -WindowStyle Hidden -Wait -PassThru
    if ($uiProcess.ExitCode -ne 0) { throw "Native UI smoke tests failed ($($uiProcess.ExitCode))." }
    Write-Host 'PASS: native UI fields, font selection, slider/combo wheel routing, exclusive chat modes, typed rules, comment-preserving initialization, missing-file creation, effect/filter previews and DPI layout.'
} finally { Pop-Location }
Get-Item -LiteralPath $exe | Select-Object FullName, Length
