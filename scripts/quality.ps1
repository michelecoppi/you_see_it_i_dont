$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolStorage = Join-Path $env:USERPROFILE ".rokit\tool-storage"
$styluaExe = Join-Path $toolStorage "johnnymorganz\stylua\2.5.2\stylua.exe"
$seleneExe = Join-Path $toolStorage "kampfkarren\selene\0.31.0\selene.exe"
$rojoExe = Join-Path $toolStorage "rojo-rbx\rojo\7.7.0\rojo.exe"
$qualityRunId = [Guid]::NewGuid().ToString("N")
$gameBuild = Join-Path $env:TEMP "reality-expedition-$qualityRunId-game.rbxlx"
$testBuild = Join-Path $env:TEMP "reality-expedition-$qualityRunId-tests.rbxlx"
$runtimeTestBuild = Join-Path $env:TEMP "reality-expedition-$qualityRunId-runtime-tests.rbxlx"

foreach ($tool in @($styluaExe, $seleneExe, $rojoExe)) {
	if (-not (Test-Path -LiteralPath $tool)) {
		throw "Missing Rokit tool: $tool. Run 'rokit install' first."
	}
}

Push-Location $projectRoot
try {
	& $styluaExe --check src tests runtime-tests
	if ($LASTEXITCODE -ne 0) { throw "StyLua check failed." }

	& $seleneExe src tests runtime-tests
	if ($LASTEXITCODE -ne 0) { throw "Selene check failed." }

	& $rojoExe build default.project.json --output $gameBuild
	if ($LASTEXITCODE -ne 0) { throw "Game Rojo build failed." }

	& $rojoExe build tests.project.json --output $testBuild
	if ($LASTEXITCODE -ne 0) { throw "Test Rojo build failed." }

	& $rojoExe build runtime-tests.project.json --output $runtimeTestBuild
	if ($LASTEXITCODE -ne 0) { throw "Runtime test Rojo build failed." }

	Write-Output "Quality checks passed."
} finally {
	Remove-Item -LiteralPath $gameBuild, $testBuild, $runtimeTestBuild -Force -ErrorAction SilentlyContinue
	Pop-Location
}
