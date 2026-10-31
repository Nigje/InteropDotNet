#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Checked([string] $Command, [string[]] $Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    Invoke-Checked dotnet @('build', 'InteropDotNet.sln', '-c', 'Release', '-m:1', '-p:UseSharedCompilation=false')

    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()
    $testOutput = 'Tests/InteropDotNet.SmokeTests/bin/Release/net10.0'
    $nativeDirectory = Join-Path $testOutput $architecture
    New-Item -ItemType Directory -Force -Path $nativeDirectory | Out-Null
    $source = 'Sample/NativeLib/source.c'

    if ($IsWindows) {
        $compiler = Get-Command cl.exe -ErrorAction SilentlyContinue
        if (!$compiler) {
            $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
            $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
            if (!$installation) { throw 'Install the Visual C++ build tools or run from a Native Tools prompt.' }
            $version = (Get-Content (Join-Path $installation 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')).Trim()
            $compilerPath = Join-Path $installation "VC/Tools/MSVC/$version/bin/Hostx64/$architecture/cl.exe"
        }
        else {
            $compilerPath = $compiler.Source
        }
        # cl locates link.exe through PATH. This fixture needs no SDK headers or CRT.
        $savedPath = $env:PATH
        try {
            $env:PATH = (Split-Path $compilerPath -Parent) + [IO.Path]::PathSeparator + $env:PATH
            $nativeFile = Join-Path $nativeDirectory 'NativeLib.dll'
            Invoke-Checked $compilerPath @('/nologo', '/LD', '/GS-', '/D_WINDOWS', $source,
                '/Fo:Tests/InteropDotNet.SmokeTests/obj/NativeLib.obj', '/link', '/NOENTRY', '/NODEFAULTLIB',
                '/IMPLIB:Tests/InteropDotNet.SmokeTests/obj/NativeLib.lib', "/OUT:$nativeFile")
        }
        finally { $env:PATH = $savedPath }
    }
    else {
        $nativeFile = Join-Path $nativeDirectory $(if ($IsMacOS) { 'libNativeLib.dylib' } else { 'libNativeLib.so' })
        $sharedFlag = if ($IsMacOS) { '-dynamiclib' } else { '-shared' }
        Invoke-Checked cc @($sharedFlag, '-fPIC', '-Wall', '-Werror', '-DUNIX', $source, '-o', $nativeFile)
    }

    Invoke-Checked dotnet @("$testOutput/InteropDotNet.SmokeTests.dll")
    $sampleNativeDirectory = Join-Path 'Sample/ManagedApplication/bin/Release/net10.0' $architecture
    New-Item -ItemType Directory -Force -Path $sampleNativeDirectory | Out-Null
    Copy-Item -LiteralPath $nativeFile -Destination $sampleNativeDirectory -Force
    Invoke-Checked dotnet @('Sample/ManagedApplication/bin/Release/net10.0/ManagedApplication.dll')
    Invoke-Checked dotnet @('pack', 'InteropDotNet/InteropDotNet.csproj', '-c', 'Release', '--no-build', '-m:1')

    $package = [IO.Compression.ZipFile]::OpenRead((Resolve-Path 'InteropDotNet/bin/Release/InteropDotNet.0.1.0.nupkg'))
    try {
        foreach ($entry in @('lib/net20/InteropDotNet.dll', 'lib/net10.0/InteropDotNet.dll', 'README.md')) {
            if (!$package.GetEntry($entry)) { throw "Package is missing $entry." }
        }
    }
    finally { $package.Dispose() }
}
finally { Pop-Location }
