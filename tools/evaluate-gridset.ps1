# Evaluates a built grid set for access and readability, without Grid 3. It reports text contrast, ways out
# of each grid (dead ends, Back loops), switch scan steps, cells that move between grids, cells that do nothing,
# long captions and grids without Rest. The checklist and the reasons are in .claude/skills/accessibility-review.
# Scan steps are an estimate for group scanning then SimpleScan (cell by cell in reading order). Grid 3's real
# order also depends on the user's access settings, which are not in the grid set.
# Usage: pwsh -NoProfile -File tools\evaluate-gridset.ps1 -GridSet grids\Muse.gridset [-Out report.md]
param(
    [Parameter(Mandatory)][string]$GridSet,
    [string]$Out,
    [double]$MinContrast = 4.5,     # WCAG 2.2 1.4.3 for normal text
    [int]$MaxGroup = 12,            # cells in one scan group before a switch user waits too long
    [int]$MaxExitSteps = 6,         # switch steps to reach a grid's way out
    [int]$MaxCaption = 16,          # characters before a caption gets small or wraps
    [double]$StepSeconds = 0        # the user's scan speed (UserSettings.xml ForwardScanSpeed) to show times
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-Entry($zip, $name) {
    $entry = $zip.GetEntry($name); if (-not $entry) { return $null }
    $reader = [IO.StreamReader]::new($entry.Open(), $true); try { [xml]$reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Lum($hex) {
    $c = 1, 3, 5 | ForEach-Object { $v = [Convert]::ToInt32($hex.Substring($_, 2), 16) / 255; if ($v -le 0.03928) { $v / 12.92 } else { [math]::Pow(($v + 0.055) / 1.055, 2.4) } }
    0.2126 * $c[0] + 0.7152 * $c[1] + 0.0722 * $c[2]
}
function Contrast($a, $b) { $x = Lum $a; $y = Lum $b; ([math]::Max($x, $y) + 0.05) / ([math]::Min($x, $y) + 0.05) }
function Transparent($hex) { $hex.Length -eq 9 -and $hex.Substring(7) -eq '00' }

$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $GridSet))
try {
    $styleDoc = Read-Entry $zip 'Settings0/Styles/styles.xml'
    $settings = Read-Entry $zip 'Settings0/settings.xml'
    $styles = @{}; if ($styleDoc) { foreach ($s in $styleDoc.SelectNodes('//Styles/Style')) { $styles[$s.Key] = $s } }   # some sets have no styles.xml
    $startGrid = $settings.DocumentElement.StartGrid
    $grids = [ordered]@{}
    foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '^Grids/[^/]+/grid\.xml$' } | Sort-Object FullName)) {
        $grids[$entry.FullName.Split('/')[1]] = Read-Entry $zip $entry.FullName
    }
} finally { $zip.Dispose() }

$findings = [Collections.Generic.List[object]]::new()
function Add-Finding($severity, $check, $grid, $text) { $findings.Add([pscustomobject]@{ Severity = $severity; Check = $check; Grid = $grid; Text = $text }) }

# Gather cells.
$cells = @{}; $jumpsTo = @{}; $parents = @{}
foreach ($name in $grids.Keys) { $parents[$name] = [Collections.Generic.HashSet[string]]::new() }
foreach ($name in $grids.Keys) {
    $x = $grids[$name]
    $gridBack = if ($x.Grid.BackgroundColour) { $x.Grid.BackgroundColour } else { '#FFFFFFFF' }
    $list = foreach ($c in $x.Grid.Cells.Cell) {
        $content = $c.SelectSingleNode('Content')
        $captionNode = $c.SelectSingleNode('Content/CaptionAndImage/Caption')
        $caption = if ($captionNode) { $captionNode.InnerText.Trim() } else { '' }
        $style = $c.SelectSingleNode('Content/Style'); $basedOn = if ($style) { $style.SelectSingleNode('BasedOnStyle') } else { $null }
        $named = if ($basedOn) { $styles[$basedOn.InnerText] } else { $null }
        $pick = { param($role) $own = if ($style) { $style.SelectSingleNode($role) } else { $null }; if ($own) { $own.InnerText } elseif ($named -and $named.SelectSingleNode($role)) { $named.SelectSingleNode($role).InnerText } }
        $back = & $pick 'BackColour'; if (-not $back -or (Transparent $back)) { $back = $gridBack }
        $font = & $pick 'FontColour'; if (-not $font) { $font = '#000000FF' }
        $commands = @($c.SelectNodes('Content/Commands/Command') | ForEach-Object { $_.ID })
        $type = if ($content) { [string]$content.ContentType } else { '' }
        [pscustomobject]@{
            X = [int]('0' + $c.X); Y = [int]('0' + $c.Y); Caption = $caption; Back = $back; Font = $font
            Image = [bool]$c.SelectSingleNode('Content/CaptionAndImage/Image'); Commands = $commands; Type = $type
            Audio = [string]$c.SelectSingleNode('Content/CaptionAndImage/AudioDescription').InnerText
            Group = if ($c.ScanBlock) { [int]$c.ScanBlock } else { 1 }
            Active = $commands.Count -gt 0 -or $type -eq 'AutoContent'
            Targets = @($c.SelectNodes("Content/Commands/Command[@ID='Jump.To']/Parameter[@Key='grid']") | ForEach-Object { $_.InnerText })
        }
    }
    $cells[$name] = @($list)
    $jumpsTo[$name] = @($cells[$name] | ForEach-Object { $_.Targets } | Where-Object { $_ } | Sort-Object -Unique)
    foreach ($t in $jumpsTo[$name]) { if ($parents.ContainsKey($t)) { [void]$parents[$t].Add($name) } }
}
$exitIds = 'Jump.Back', 'Jump.Home', 'Settings.ChangeGridSet', 'Settings.GridExplorer'
# The home grid is where the start grid jumps. A Jump.To home or to a grid that opens this one is a way out too.
$homeGrid = @($jumpsTo[$startGrid])[0]
function Test-Exit($c, $grid) { @($c.Commands | Where-Object { $_ -in $exitIds }).Count -or @($c.Targets | Where-Object { $_ -eq $homeGrid -or $parents[$grid].Contains($_) }).Count }

# 1. Text contrast.
foreach ($name in $grids.Keys) {
    foreach ($c in $cells[$name] | Where-Object { $_.Caption -and $_.Type -ne 'Workspace' }) {
        $ratio = Contrast $c.Back $c.Font
        if ($ratio -lt $MinContrast) { Add-Finding 'fix' 'contrast' $name ("{0},{1} '{2}': {3:N1}:1 ({4} on {5}), needs {6}:1" -f $c.X, $c.Y, $c.Caption, $ratio, $c.Font, $c.Back, $MinContrast) }
    }
}

# 2. Ways out: dead ends, Back loops, and whether the start grid can be reached again.
foreach ($name in $grids.Keys) {
    $ids = @($cells[$name] | ForEach-Object { $_.Commands }) | Sort-Object -Unique
    $hasBack = 'Jump.Back' -in $ids
    $leaves = $jumpsTo[$name].Count -or @($ids | Where-Object { $_ -in $exitIds }).Count
    if (-not $leaves -and $name -ne $startGrid) { Add-Finding 'fix' 'exit' $name 'No cell leaves this grid: a switch user is stuck' }
    # Jump.To pushes onto Grid 3's history and Jump.Back pops it. If a sub-grid returns here with Jump.To, this
    # grid's Back goes to the sub-grid again. With no other way out of the sub-grid, the user loops.
    if ($hasBack) {
        foreach ($child in $jumpsTo[$name]) {
            if ($child -eq $name -or -not $cells.ContainsKey($child) -or $name -notin $jumpsTo[$child]) { continue }
            $childIds = @($cells[$child] | ForEach-Object { $_.Commands })
            $elsewhere = @($jumpsTo[$child] | Where-Object { $_ -ne $name -and $_ -ne $child }).Count -or @($childIds | Where-Object { $_ -in $exitIds }).Count
            if (-not $elsewhere) { Add-Finding 'fix' 'back-loop' $name "'$child' returns here only with Jump.To, so this grid's Back goes to '$child' and the user loops" }
            elseif ('Jump.Back' -in $childIds -and $parents[$name].Count -gt 1) { Add-Finding 'improve' 'back-loop' $name "'$child' returns here with Jump.To, so this grid's Back first goes to '$child' again (extra presses)" }
        }
    }
}
$reach = @{}
foreach ($name in $grids.Keys) {
    $seen = [Collections.Generic.HashSet[string]]::new(); $queue = [Collections.Generic.Queue[string]]::new(); $queue.Enqueue($name)
    while ($queue.Count) {
        $g = $queue.Dequeue(); if (-not $seen.Add($g)) { continue }
        foreach ($t in $jumpsTo[$g]) { if ($grids.Contains($t)) { $queue.Enqueue($t) } }
        $gIds = @($cells[$g] | ForEach-Object { $_.Commands })
        if ('Jump.Back' -in $gIds) { foreach ($p in $parents[$g]) { $queue.Enqueue($p) } }
        if ('Jump.Home' -in $gIds) { $queue.Enqueue($startGrid) }   # Jump.Home opens the start grid (settings.xml StartGrid)
    }
    $leavesSet = @($grids.Keys | Where-Object { $seen.Contains($_) } | ForEach-Object { $cells[$_] } | Where-Object { @($_.Commands | Where-Object { $_ -in 'Settings.ChangeGridSet', 'Settings.GridExplorer' }).Count }).Count
    if (-not $seen.Contains($startGrid) -and -not $leavesSet) { Add-Finding 'fix' 'exit' $name "Cannot get back to the start grid ($startGrid) or out of the grid set" }
}

# 3. Switch scanning: groups by ScanBlock, then reading order. Steps = groups passed + group select + cells passed + cell select.
$scanRows = foreach ($name in $grids.Keys) {
    $active = @($cells[$name] | Where-Object { $_.Active })
    if (-not $active.Count) { continue }
    $groups = @($active | Group-Object Group | Sort-Object { [int]$_.Name })
    $steps = @{}; $gi = 0
    foreach ($g in $groups) {
        $gi++; $ci = 0
        foreach ($c in @($g.Group | Sort-Object Y, X)) { $ci++; $steps[$c] = $gi + $ci }
        if ($groups.Count -gt 1 -and $g.Count -gt $MaxGroup) { Add-Finding 'improve' 'scan' $name "Group $($g.Name) has $($g.Count) cells (more than $MaxGroup)" }
    }
    if ($groups.Count -eq 1 -and $active.Count -gt $MaxGroup) { Add-Finding 'improve' 'scan' $name "One scan group of $($active.Count) cells: a switch user steps through every cell in reading order" }
    $exits = @($active | Where-Object { Test-Exit $_ $name })
    $exitSteps = if ($exits.Count) { ($exits | ForEach-Object { $steps[$_] } | Measure-Object -Minimum).Minimum } else { $null }
    if ($exitSteps -gt $MaxExitSteps) { Add-Finding 'improve' 'scan' $name "The nearest way out takes $exitSteps switch steps (more than $MaxExitSteps)" }
    # Untested: whether Grid 3 speaks these names when a group is highlighted. No stock grid set fills them in.
    if ($groups.Count -gt 1 -and -not $grids[$name].SelectSingleNode('//ScanBlockAudioDescriptions//Text[normalize-space()]')) {
        Add-Finding 'check' 'auditory' $name "$($groups.Count) scan groups with no names in ScanBlockAudioDescriptions: a user who scans by sound may hear nothing for a group"
    }
    [pscustomobject]@{ Grid = $name; Cells = $active.Count; Groups = $groups.Count; Largest = ($groups | Measure-Object Count -Maximum).Maximum
        Worst = ($steps.Values | Measure-Object -Maximum).Maximum; Exit = $exitSteps }
}

# 4. The same caption in different places on different grids (motor planning: a cell keeps its place).
$places = @{}
foreach ($name in $grids.Keys) { foreach ($c in $cells[$name] | Where-Object { $_.Caption -and $_.Active }) { $k = $c.Caption.ToLower(); if (-not $places[$k]) { $places[$k] = @{} }; $places[$k]["$($c.X),$($c.Y)"] += @($name) } }
foreach ($k in $places.Keys) {
    if ($places[$k].Count -gt 1) { Add-Finding 'improve' 'position' '' ("'{0}' moves: {1}" -f $k, (($places[$k].GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) on $(($_.Value | ForEach-Object { $_ -replace '^.+? - ', '' }) -join ', ')" }) -join '; ')) }
}

# 5. Cells that do nothing, and active cells with nothing to see.
foreach ($name in $grids.Keys) {
    foreach ($c in $cells[$name]) {
        if ($c.Caption -and -not $c.Active -and $c.Type -notin 'Workspace', 'LiveCell') { Add-Finding 'check' 'dead-cell' $name ("{0},{1} '{2}' has a caption but no command" -f $c.X, $c.Y, $c.Caption) }
        if ($c.Active -and -not $c.Caption -and -not $c.Image -and $c.Type -ne 'AutoContent') {
            # A blank space bar is the stock design. Without an AudioDescription it says nothing to a user who scans by sound.
            if ('Action.Space' -notin $c.Commands) { Add-Finding 'fix' 'blank-cell' $name ("{0},{1} does something ({2}) but shows nothing" -f $c.X, $c.Y, ($c.Commands -join ', ')) }
        }
        if ($c.Active -and -not $c.Caption -and -not $c.Audio -and $c.Type -ne 'AutoContent') {
            $severity = if ($c.Image) { 'check' } else { 'improve' }
            Add-Finding $severity 'auditory' $name ("{0},{1} ({2}) has no caption text or AudioDescription: auditory scanning may say nothing{3}" -f $c.X, $c.Y, ($c.Commands -join ', '), $(if ($c.Image) { ' (it has an image)' }))
        }
        if ($c.Caption.Length -gt $MaxCaption) { Add-Finding 'check' 'caption' $name ("{0},{1} '{2}' is {3} characters" -f $c.X, $c.Y, $c.Caption, $c.Caption.Length) }
    }
}

# 6. Rest (pause) on each grid, for eye gaze and for a switch user who wants to stop.
foreach ($name in $grids.Keys) {
    if (-not @($cells[$name] | Where-Object { 'Settings.RestAll' -in $_.Commands }).Count) { Add-Finding 'check' 'rest' $name 'No Rest cell' }
}

# Report.
$order = @{ fix = 0; improve = 1; check = 2 }
$md = [Text.StringBuilder]::new()
[void]$md.AppendLine("# Grid set evaluation: $(Split-Path $GridSet -Leaf)").AppendLine()
[void]$md.AppendLine("Start grid: $startGrid. Grids: $($grids.Count). Findings: " + (($findings | Group-Object Severity | Sort-Object { $order[$_.Name] } | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', ') + '.').AppendLine()
[void]$md.AppendLine('## Switch scan steps (estimate)').AppendLine()
$time = { param($n) if ($StepSeconds -and $null -ne $n) { ' ({0:N0} s)' -f ($n * $StepSeconds) } else { '' } }
if ($StepSeconds) { [void]$md.AppendLine("Times use $StepSeconds s per step.").AppendLine() }
[void]$md.AppendLine('| Grid | Active cells | Groups | Largest group | Most steps | Steps to a way out |').AppendLine('|---|---|---|---|---|---|')
foreach ($r in $scanRows) { [void]$md.AppendLine("| $($r.Grid) | $($r.Cells) | $($r.Groups) | $($r.Largest) | $($r.Worst)$(& $time $r.Worst) | $(if ($null -ne $r.Exit) { "$($r.Exit)$(& $time $r.Exit)" } else { 'none' }) |") }
[void]$md.AppendLine().AppendLine('## Findings').AppendLine()
if (-not $findings.Count) { [void]$md.AppendLine('None.') }
foreach ($f in $findings | Sort-Object { $order[$_.Severity] }, Check, Grid) { [void]$md.AppendLine("- **$($f.Severity)** $($f.Check)$(if ($f.Grid) { " ($($f.Grid))" }): $($f.Text)") }
if ($Out) { [IO.File]::WriteAllText($Out, $md.ToString(), [Text.UTF8Encoding]::new($false)) }
$md.ToString()
