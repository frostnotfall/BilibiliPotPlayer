$ErrorActionPreference = 'Stop'
$nativeRoot = $PSScriptRoot
$repoRoot = [IO.Path]::GetFullPath((Join-Path $nativeRoot '..\..'))
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$installation) { throw 'Visual Studio C++ build tools were not found.' }
$vcvars = Join-Path $installation 'VC\Auxiliary\Build\vcvarsall.bat'
$objectDir = Join-Path $nativeRoot 'build\x64'
$outputDir = Join-Path $repoRoot 'Extension\Lib'
New-Item -ItemType Directory -Force -Path $objectDir, $outputDir | Out-Null
$dll = Join-Path $outputDir 'BilibiliRegex.dll'
$buildScript = @"
@echo off
call "$vcvars" x64 >nul
if errorlevel 1 exit /b %errorlevel%
cl /nologo /std:c11 /O2 /MT /W3 /utf-8 /D_CRT_SECURE_NO_WARNINGS /LD /I "$nativeRoot\vendor\quickjs-ng" "$nativeRoot\BilibiliRegex.c" "$nativeRoot\vendor\quickjs-ng\libregexp.c" "$nativeRoot\vendor\quickjs-ng\libunicode.c" /link /DEF:"$nativeRoot\BilibiliRegex.def" /OUT:"$dll" /IMPLIB:"$objectDir\BilibiliRegex.lib" /INCREMENTAL:NO /OPT:REF /OPT:ICF /DYNAMICBASE /NXCOMPAT
if errorlevel 1 exit /b %errorlevel%
dumpbin /nologo /exports "$dll"
if errorlevel 1 exit /b %errorlevel%
dumpbin /nologo /dependents "$dll"
if errorlevel 1 exit /b %errorlevel%
cl /nologo /std:c11 /O2 /MT /W4 /utf-8 /D_CRT_SECURE_NO_WARNINGS "$nativeRoot\tests\native_test.c" /Fe:"$objectDir\verify.exe" /link /INCREMENTAL:NO
exit /b %errorlevel%
"@
$scriptPath = Join-Path $objectDir 'build.cmd'
[IO.File]::WriteAllText($scriptPath, $buildScript, [Text.Encoding]::Default)
Push-Location -LiteralPath $objectDir
try {
    & $scriptPath
    if ($LASTEXITCODE -ne 0) { throw "x64 build failed ($LASTEXITCODE)" }
} finally { Pop-Location }
$notice = "BilibiliRegex.dll`n`nWrapper, build scripts and tests:`n`n" +
    [IO.File]::ReadAllText((Join-Path $nativeRoot 'LICENSE')) +
    "`n`nQuickJS-NG v0.17.0 (regexp/Unicode modules):`n`n" +
    [IO.File]::ReadAllText((Join-Path $nativeRoot 'vendor\quickjs-ng\LICENSE'))
[IO.File]::WriteAllText((Join-Path $outputDir 'BilibiliRegex.LICENSE.txt'), $notice, [Text.UTF8Encoding]::new($false))
$upstream = Get-Content -LiteralPath (Join-Path $nativeRoot 'vendor\quickjs-ng\UPSTREAM.json') -Raw | ConvertFrom-Json
$manifest = [ordered]@{
    abi = 1
    engine = 'QuickJS-NG v0.17.0 libregexp'
    source_commit = $upstream.commit
    verification = @{ result = 'NOT_RUN'; command = 'python Native/BilibiliRegex/tests/verify.py' }
    artifacts = @(@{
        architecture = 'x64'; path = 'Extension/Lib/BilibiliRegex.dll'
        bytes = (Get-Item -LiteralPath $dll).Length
        sha256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}
[IO.File]::WriteAllText((Join-Path $outputDir 'BilibiliRegex.manifest.json'),
    ($manifest | ConvertTo-Json -Depth 5) + "`n", [Text.UTF8Encoding]::new($false))
Get-Item -LiteralPath $dll | Select-Object FullName, Length
