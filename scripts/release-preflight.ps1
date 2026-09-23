param(
	[ValidateSet('PrivateTest', 'SoftLaunch', 'Production')]
	[string]$Environment = 'Production'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $projectRoot 'src/shared/Environment.luau'
$profilesFile = Join-Path $projectRoot 'src/shared/EnvironmentConfig.luau'
$iconFile = Join-Path $projectRoot 'docs/images/game_icon.png'
$findings = [System.Collections.Generic.List[string]]::new()

$environmentSource = Get-Content -LiteralPath $environmentFile -Raw
$profilesSource = Get-Content -LiteralPath $profilesFile -Raw

if ($environmentSource -notmatch ('Environment\.PublishedEnvironment\s*=\s*Environment\.Names\.' + [regex]::Escape($Environment))) {
	$findings.Add("PublishedEnvironment does not select $Environment.")
}

$escapedEnvironment = [regex]::Escape($Environment)
$profilePattern = '(?s)\[Environment\.Names\.' + $escapedEnvironment + '\]\s*=\s*\{(?<body>.*?)(?=\r?\n\s*\[Environment\.Names\.|\r?\n\})'
$profileMatch = [regex]::Match($profilesSource, $profilePattern)
if (-not $profileMatch.Success) {
	$findings.Add("Marketplace profile $Environment was not found.")
} else {
	$profileBody = $profileMatch.Groups['body'].Value
	foreach ($assetName in @('VoidDrone', 'PrismaticVision', 'Shards500', 'Shards1250', 'Shards3000')) {
		$match = [regex]::Match($profileBody, '(?m)^\s*' + $assetName + '\s*=\s*(?<id>\d+)')
		if (-not $match.Success -or $match.Groups['id'].Value -eq '0') {
			$findings.Add("$assetName has no valid Marketplace ID in $Environment.")
		}
	}
}

if (-not (Test-Path -LiteralPath $iconFile)) {
	$findings.Add('Game icon source file is missing.')
}

Write-Output "Release preflight: $Environment"
foreach ($finding in $findings) {
	Write-Output "PENDING: $finding"
}
Write-Output 'MANUAL: Run the complete Studio playtest matrix on desktop, touch and gamepad.'
Write-Output 'MANUAL: Verify DataStore, pass ownership, Developer Product receipts and rejoin in a published staging universe.'
Write-Output 'MANUAL: Upload the icon and authentic in-game thumbnails, complete experience settings and content questionnaire in Creator Dashboard.'

if ($findings.Count -gt 0) {
	exit 1
}
Write-Output 'Configuration checks passed; manual release checks remain.'
