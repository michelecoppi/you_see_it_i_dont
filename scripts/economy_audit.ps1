$ErrorActionPreference = "Stop"

$configPath = Join-Path (Split-Path -Parent $PSScriptRoot) "src\shared\Config.luau"
$source = Get-Content -LiteralPath $configPath -Raw

function Read-Number([string] $pattern, [string] $label) {
	$match = [regex]::Match($source, $pattern, "Multiline")
	if (-not $match.Success) {
		throw "Could not read $label from $configPath"
	}
	return [int]$match.Groups[1].Value
}

$starting = Read-Number 'StartingShards\s*=\s*(\d+)' "starting Shards"
$daily = Read-Number 'DailyReward\s*=\s*(\d+)' "daily reward"
$escape = Read-Number 'Escape\s*=\s*(\d+)' "escape reward"
$clean = Read-Number 'NoMistakes\s*=\s*(\d+)' "clean expedition bonus"
$group = Read-Number 'GroupBonus\s*=\s*(\d+)' "group bonus"

$items = [regex]::Matches($source, '(?ms)^\s*([a-z][a-z_0-9]+)\s*=\s*\{(.*?)^\s*\},') |
	ForEach-Object {
		$id = $_.Groups[1].Value
		$body = $_.Groups[2].Value
		if ($body -match 'Currency\s*=\s*"Shards"' -and $body -match 'Price\s*=\s*(\d+)') {
			[pscustomobject]@{ Item = $id; Price = [int]$Matches[1] }
		}
	} | Sort-Object Price, Item

if ($items.Count -lt 1) { throw "No Shards cosmetics found in $configPath" }

Write-Output "Starting Shards: $starting | Daily claim: $daily | Solo escape: $escape-$($escape + $clean) | Group escape: $($escape + $group)-$($escape + $group + $clean)"
Write-Output "Minimum completed expeditions from a new account (no purchases, no prior earnings):"
$items | ForEach-Object {
	$remaining = [math]::Max(0, $_.Price - $starting)
	$remainingWithDaily = [math]::Max(0, $_.Price - $starting - $daily)
	[pscustomobject]@{
		Item = $_.Item
		Price = $_.Price
		SoloWins = [int][math]::Ceiling($remaining / $escape)
			CleanSoloWins = [int][math]::Ceiling($remaining / ($escape + $clean))
			GroupWins = [int][math]::Ceiling($remaining / ($escape + $group))
			CleanGroupWins = [int][math]::Ceiling($remaining / ($escape + $group + $clean))
			WithOneDailyCleanSolo = [int][math]::Ceiling($remainingWithDaily / ($escape + $clean))
	}
} | Format-Table -AutoSize | Out-String | Write-Output
