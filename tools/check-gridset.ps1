# Checks a built grid set without opening Grid 3: every cell inside its grid, no two
# cells on the same square, every Jump.To names a grid in the set, and every file in
# FileMap.xml is present. Optionally lists the cells and commands of named grids.
# Usage: pwsh -File tools\check-gridset.ps1 [-GridSet <path>] [-Show 'Muse - Home','...']
param(
    [string]$GridSet = (Join-Path (Split-Path $PSScriptRoot -Parent) 'grids\Muse.gridset'),
    [string[]]$Show = @()
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-Text($entry) {
    $reader = New-Object IO.StreamReader($entry.Open(), $true)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}

$zip = [IO.Compression.ZipFile]::OpenRead($GridSet)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    $gridEntries = @($zip.Entries | Where-Object { $_.FullName -match '^Grids/[^/]+/grid\.xml$' })
    $grids = @($gridEntries | ForEach-Object { $_.FullName.Split('/')[1] })
    $problems = New-Object Collections.Generic.List[string]

    foreach ($entry in $gridEntries) {
        $grid = $entry.FullName.Split('/')[1]
        [xml]$x = Read-Text $entry
        $columns = @($x.Grid.ColumnDefinitions.ColumnDefinition).Count
        $rows = @($x.Grid.RowDefinitions.RowDefinition).Count
        $taken = @{}
        foreach ($cell in $x.Grid.Cells.Cell) {
            $left = [int]('0' + $cell.X); $top = [int]('0' + $cell.Y)
            $width = if ($cell.ColumnSpan) { [int]$cell.ColumnSpan } else { 1 }
            $height = if ($cell.RowSpan) { [int]$cell.RowSpan } else { 1 }
            for ($i = $left; $i -lt $left + $width; $i++) {
                for ($j = $top; $j -lt $top + $height; $j++) {
                    if ($i -ge $columns -or $j -ge $rows) { $problems.Add("$grid`: cell outside the grid at $i,$j") }
                    if ($taken.ContainsKey("$i,$j")) { $problems.Add("$grid`: two cells at $i,$j") }
                    $taken["$i,$j"] = $true
                }
            }
        }
        foreach ($target in $x.SelectNodes("//Command[@ID='Jump.To']/Parameter[@Key='grid']")) {
            if ($target.InnerText -notin $grids) { $problems.Add("$grid`: Jump.To a missing grid, $($target.InnerText)") }
        }
        if ($grid -in $Show) {
            Write-Output "== $grid"
            foreach ($cell in @($x.Grid.Cells.Cell | Sort-Object { [int]('0' + $_.Y) }, { [int]('0' + $_.X) })) {
                $caption = $cell.SelectSingleNode('Content/CaptionAndImage/Caption')
                if ($null -eq $caption) { continue }
                $commands = @($cell.SelectNodes('Content/Commands/Command') | ForEach-Object {
                    $parameters = @($_.SelectNodes('Parameter') | ForEach-Object { "$($_.Key)=$($_.InnerText)" }) -join '; '
                    "$($_.ID)($parameters)"
                }) -join ' > '
                Write-Output ("  {0},{1} {2}: {3}" -f ('0' + $cell.X -replace '^0(?=\d)', ''), ('0' + $cell.Y -replace '^0(?=\d)', ''), $caption.InnerText, $commands)
            }
        }
    }

    $fileMap = $zip.GetEntry('FileMap.xml')
    if ($null -eq $fileMap) { $problems.Add('No FileMap.xml') }
    else {
        [xml]$map = Read-Text $fileMap
        foreach ($file in $map.SelectNodes('//File')) {
            if ($file.InnerText.Replace('\', '/') -notin $names) { $problems.Add("FileMap.xml lists a missing file, $($file.InnerText)") }
        }
    }

    Write-Output "Grids: $($grids.Count). Problems: $($problems.Count)."
    $problems | ForEach-Object { Write-Output "  $_" }
    if ($problems.Count -gt 0) { exit 1 }
}
finally { $zip.Dispose() }
