# Builds a site grid set from a template (templates\*.psd1) and a site folder (sites\<name>\site.psd1 + page.js).
# It copies the template's stock Smartbox grid set, renames its grids and commandids to the site, removes
# cells whose commandids the site's page.js does not answer, drops grids no cell reaches, and puts page.js
# inside each script commandid (Grid 3 3.0.93 never runs Settings0\WebBrowser\code.js, which it also ships).
# Writes only grids\<Output>. Details: docs\templates.md.
# Usage: pwsh -NoProfile -File tools\build-site.ps1 -Site muse
param([Parameter(Mandatory)][string]$Site)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo = Split-Path $PSScriptRoot -Parent
$siteDir = Join-Path $repo "sites\$Site"
$config = Import-PowerShellDataFile (Join-Path $siteDir 'site.psd1')
$template = Import-PowerShellDataFile (Join-Path $repo "templates\$($config.Template).psd1")
# Shared pieces from templates\ (such as alert.js) go before the site's page.js, in the order listed.
$pageScript = (@(@($config.Include) | Where-Object { $_ } | ForEach-Object { Get-Content -Raw (Join-Path $repo "templates\$_") }) +
    @(Get-Content -Raw (Join-Path $siteDir 'page.js'))) -join "`n"

$name = $config.Name
$scriptName = $config.ScriptName

# The functions page.js answers, read from its COMMANDS table ('Home/Next_Message': ...).
$implemented = @([regex]::Matches($pageScript, "(?m)^\s*'([A-Za-z0-9_]+/[A-Za-z0-9_]+)'\s*:") | ForEach-Object { $_.Groups[1].Value })
$ignore = @($config.Ignore)
foreach ($id in $implemented + $ignore) {
    if ($id -notin $template.Contract -and $id -notin @($config.Extra)) { throw "$id is not in the $($template.Name) contract or the site's Extra list." }
}

$work = Join-Path ([IO.Path]::GetTempPath()) "smartbox-build-$Site-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
[IO.Compression.ZipFile]::ExtractToDirectory($template.Source, $work)

[xml]$stockSettings = Get-Content -Raw (Join-Path $work 'Settings0\settings.xml')
if ($stockSettings.GridSetSettings.Description -notmatch [regex]::Escape($template.SourceVersion)) {
    Write-Warning "Stock set is not $($template.SourceVersion); check the template's cell positions still match."
}

function Get-Guid($text) {
    $hash = [Security.Cryptography.MD5]::HashData([Text.Encoding]::UTF8.GetBytes($text))
    [guid]::new($hash).ToString()
}

function Format-Xml($document) {
    $settings = [Xml.XmlWriterSettings]@{ Indent = $true; OmitXmlDeclaration = $true; Encoding = [Text.UTF8Encoding]::new($true) }
    $stream = [IO.MemoryStream]::new()
    $writer = [Xml.XmlWriter]::Create($stream, $settings)
    try { $document.Save($writer) } finally { $writer.Dispose() }
    $stream.ToArray()
}

function Save-Xml($document, $path) { [IO.File]::WriteAllBytes($path, (Format-Xml $document)) }

function New-Cell($document, $spec) {
    $cell = $document.CreateElement('Cell')
    if ($spec.X) { $cell.SetAttribute('X', "$($spec.X)") }
    if ($spec.Y) { $cell.SetAttribute('Y', "$($spec.Y)") }
    if ($spec.Width -and $spec.Width -ne 1) { $cell.SetAttribute('ColumnSpan', "$($spec.Width)") }
    if ($spec.Height -and $spec.Height -ne 1) { $cell.SetAttribute('RowSpan', "$($spec.Height)") }
    $content = $cell.AppendChild($document.CreateElement('Content'))
    $commands = $content.AppendChild($document.CreateElement('Commands'))
    foreach ($command in $spec.Commands) {
        $node = $commands.AppendChild($document.CreateElement('Command'))
        $node.SetAttribute('ID', $command.ID)
        foreach ($key in @($command.Keys | Where-Object { $_ -ne 'ID' } | Sort-Object)) {
            $parameter = $node.AppendChild($document.CreateElement('Parameter'))
            $parameter.SetAttribute('Key', $key)
            $parameter.InnerText = $command[$key]
        }
    }
    $captionAndImage = $content.AppendChild($document.CreateElement('CaptionAndImage'))
    $captionAndImage.AppendChild($document.CreateElement('Caption')).InnerText = $spec.Caption
    if ($spec.Image) { $captionAndImage.AppendChild($document.CreateElement('Image')).InnerText = $spec.Image }
    $style = $content.AppendChild($document.CreateElement('Style'))
    $style.AppendChild($document.CreateElement('BasedOnStyle')).InnerText = $(if ($spec.Style) { $spec.Style } else { 'style 1' })
    $cell
}

function Get-CellAt($cells, $x, $y) {
    foreach ($cell in @($cells.SelectNodes('Cell'))) {
        if ([int]('0' + $cell.X) -eq $x -and [int]('0' + $cell.Y) -eq $y) { return $cell }
    }
}

# Rewrites one command for the site. Returns 'unanswered' for a script call page.js does not answer.
function Update-Command($command) {
    switch -Regex ($command.ID) {
        '^WebBrowser\.(ExecuteJavaScript|SpeakJavascriptFunction)$' {
            $parameter = $command.SelectSingleNode("Parameter[@Key='commandid']")
            $id = $parameter.InnerText -replace "^$([regex]::Escape($template.ScriptName))/", ''
            if ($id -in $ignore) { [void]$command.ParentNode.RemoveChild($command) }
            elseif ($id -in $implemented) { $parameter.InnerText = "$scriptName/$id" }
            else { return 'unanswered' }
        }
        '^Jump\.To$' {
            $parameter = $command.SelectSingleNode("Parameter[@Key='grid']")
            if ($rename.ContainsKey($parameter.InnerText)) { $parameter.InnerText = $rename[$parameter.InnerText] }
        }
        '^WebBrowser\.NavigateUrl$' {
            $parameter = $command.SelectSingleNode("Parameter[@Key='url']")
            $hostName = ([uri]($(if ($parameter.InnerText -match '://') { $parameter.InnerText } else { "https://$($parameter.InnerText)" }))).Host
            if ($hostName -in $template.StockHosts) { $parameter.InnerText = $config.Url }
        }
    }
    'ok'
}

# Grid 3 3.0.93 creates its browser before it reads code.js, so code.js never loads (WebBrowserContainer's
# constructor, read 2026-11-06). Grid 3 runs a commandid as "GridCommands." + commandid + "()" with spaces and
# hyphens made "_" and "/" made ".". So:
# - Each grid with script cells gets one loader in its on-open Commands. It runs page.js (percent-encoded,
#   no spaces, hyphens or slashes) once per page version and saves it in the site's localStorage.
# - Each cell carries only a short call, like WhatsApp's: it loads page.js from localStorage if the page was
#   reloaded since, then calls the function, such as GridCommands.Muse.Home.Next_Message().
# The hoisted function declaration (a tab after "function") stops "GridCommands._" failing on a fresh page.
$safe = '[A-Za-z0-9!#$()*+,.:;=?@\[\]^_`{|}~]'
$loaderSource = (($pageScript -split "`r?`n" | Where-Object { $_ -notmatch '^\s*//' } | ForEach-Object { $_.Trim() }) -join "`n") +
    "`nif(window.GridCommands&&GridCommands.$scriptName)GridCommands.$scriptName.Load=function(){return ''};"
$encodedScript = -join ([Text.Encoding]::UTF8.GetBytes($loaderSource) | ForEach-Object {
    $c = [char]$_; if ($_ -lt 128 -and "$c" -cmatch $safe) { $c } else { '%{0:X2}' -f $_ } })
$version = -join ([Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($encodedScript))[0..3] | ForEach-Object { $_.ToString('x2') })
$cache = "window.__grid3_$scriptName"
$store = "localStorage.grid3_$scriptName"
function Get-CallId($id) {
    "_;function`tGridCommands(){};$cache||((0,eval)($store||''),$cache=GridCommands.$scriptName);" +
    "GridCommands.$scriptName=$cache;GridCommands.$scriptName.$($id -replace '/', '.')"
}
$loaderId = "_;function`tGridCommands(){};if($cache`_v!=='$version'){var`t__g3s=decodeURIComponent('$encodedScript');(0,eval)(__g3s);" +
    "try{$store=__g3s}catch(e){};$cache=GridCommands.$scriptName;$cache`_v='$version'};GridCommands.$scriptName=$cache;GridCommands.$scriptName.Load"

# Imports: grids from another stock grid set (such as Smartbox's Email keyboard) replace or add template grids.
# Each import names its Source and a Grids map (source grid -> short grid name here). Jumps to grids in the map
# follow it; jumps to a Send grid become Enter then Jump.Back; jumps to a Back grid become Jump.Back. Jumps from
# a sub-grid to a Return grid (the main keyboard) become Jump.Back: Jump.To pushes onto Grid 3's history and
# Jump.Back pops it, so a Jump.To there makes the main grid's Back return to the sub-grid in a loop. A cell
# that jumps anywhere else, or has a command matching DropCommands, is removed. The workspace cell comes from
# the template grid being replaced (the site's browser in place of the email editor). The styles the grids use
# come along; a name that clashes with a different template style gets " (import)" added.
$gridsDir = Join-Path $work 'Grids'
$prefix = $template.GridPrefix
$stylesPath = Join-Path $work 'Settings0\Styles\styles.xml'
[xml]$styleDoc = Get-Content -Raw $stylesPath
foreach ($import in @($config.Imports | Where-Object { $_ })) {
    $src = Join-Path ([IO.Path]::GetTempPath()) "smartbox-import-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    [IO.Compression.ZipFile]::ExtractToDirectory($import.Source, $src)
    [xml]$srcStyles = Get-Content -Raw (Join-Path $src 'Settings0\Styles\styles.xml')
    $styleRename = @{}
    $importWorkspace = $null
    # Replace grids first that have a template counterpart, so their workspace can serve the new ones too.
    $order = @($import.Grids.Keys | Sort-Object { -not (Test-Path -LiteralPath (Join-Path $gridsDir "$prefix - $($import.Grids[$_])")) })
    foreach ($sourceGrid in $order) {
        $targetDir = Join-Path $gridsDir "$prefix - $($import.Grids[$sourceGrid])"
        $workspace = $null
        if (Test-Path -LiteralPath $targetDir) {
            [xml]$replacedGrid = Get-Content -Raw -LiteralPath (Join-Path $targetDir 'grid.xml')
            $workspace = $replacedGrid.SelectSingleNode("//Cell[Content/ContentType='Workspace']")
            Remove-Item -Recurse -LiteralPath $targetDir
        }
        if ($workspace) { $importWorkspace = $workspace } else { $workspace = $importWorkspace }
        Copy-Item -Recurse -LiteralPath (Join-Path $src "Grids\$sourceGrid") $targetDir
        $path = Join-Path $targetDir 'grid.xml'
        [xml]$doc = Get-Content -Raw -LiteralPath $path
        $cellsNode = $doc.DocumentElement.SelectSingleNode('Cells')
        $theirs = $doc.SelectSingleNode("//Cell[Content/ContentType='Workspace']")
        if ($theirs -and $workspace) { [void]$cellsNode.ReplaceChild($doc.ImportNode($workspace, $true), $theirs) }
        foreach ($cell in @($cellsNode.SelectNodes('Cell'))) {
            $drop = $false
            foreach ($command in @($cell.SelectNodes('Content/Commands/Command'))) {
                if (@($import.DropCommands | Where-Object { $command.ID -like $_ }).Count) { $drop = $true; break }
                if ($command.ID -ne 'Jump.To') { continue }
                $param = $command.SelectSingleNode("Parameter[@Key='grid']")
                if ($param.InnerText -in @($import.Return) -and $param.InnerText -ne $sourceGrid) {
                    $back = $doc.CreateElement('Command'); $back.SetAttribute('ID', 'Jump.Back'); [void]$command.ParentNode.ReplaceChild($back, $command)
                }
                elseif ($import.Grids.ContainsKey($param.InnerText)) { $param.InnerText = "$prefix - $($import.Grids[$param.InnerText])" }
                elseif ($param.InnerText -in @($import.Send)) {
                    $enter = $doc.CreateElement('Command'); $enter.SetAttribute('ID', 'ComputerControl.Keyboard')
                    $key = $enter.AppendChild($doc.CreateElement('Parameter')); $key.SetAttribute('Key', 'keystring'); $key.InnerText = '{ENTER}'
                    [void]$command.ParentNode.InsertBefore($enter, $command)
                    $back = $doc.CreateElement('Command'); $back.SetAttribute('ID', 'Jump.Back'); [void]$command.ParentNode.ReplaceChild($back, $command)
                }
                elseif ($param.InnerText -in @($import.Back)) {
                    $back = $doc.CreateElement('Command'); $back.SetAttribute('ID', 'Jump.Back'); [void]$command.ParentNode.ReplaceChild($back, $command)
                }
                else { $drop = $true; break }
            }
            if ($drop) { [void]$cellsNode.RemoveChild($cell) }
        }
        foreach ($based in @($doc.SelectNodes('//BasedOnStyle'))) {
            $key = $based.InnerText
            if (-not $styleRename.ContainsKey($key)) {
                $theirStyle = $srcStyles.SelectSingleNode("//Style[@Key=`"$key`"]")
                $ourStyle = $styleDoc.SelectSingleNode("//Style[@Key=`"$key`"]")
                $styleRename[$key] = $key
                if ($theirStyle -and -not $ourStyle) {
                    [void]$styleDoc.DocumentElement.SelectSingleNode('Styles').AppendChild($styleDoc.ImportNode($theirStyle, $true))
                } elseif ($theirStyle -and $ourStyle.OuterXml -ne $theirStyle.OuterXml) {
                    $styleRename[$key] = "$key (import)"
                    if (-not $styleDoc.SelectSingleNode("//Style[@Key=`"$key (import)`"]")) {
                        $copy = $styleDoc.ImportNode($theirStyle, $true); $copy.SetAttribute('Key', "$key (import)")
                        [void]$styleDoc.DocumentElement.SelectSingleNode('Styles').AppendChild($copy)
                    }
                }
            }
            $based.InnerText = $styleRename[$key]
        }
        Save-Xml $doc $path
    }
    Remove-Item -Recurse $src
}
Save-Xml $styleDoc $stylesPath

# Rename grids: "WhatsApp - Home" becomes "Muse - Home". (WhatsApp's Info 3 grid has two spaces.)
$gridsDir = Join-Path $work 'Grids'
$rename = @{}
foreach ($folder in Get-ChildItem $gridsDir -Directory) {
    if ($folder.Name -notmatch "^$([regex]::Escape($template.GridPrefix))\s+-\s+(.+)$") { throw "Unexpected grid name: $($folder.Name)" }
    $rename[$folder.Name] = "$name - $($Matches[1])"
}
$startGrid = "$name - $($template.StartGrid)"

$removedCells = [Collections.Generic.List[object]]::new()
$warnings = [Collections.Generic.List[object]]::new()
$jumps = @{}
foreach ($folder in Get-ChildItem $gridsDir -Directory) {
    $gridName = $rename[$folder.Name]
    $short = $gridName.Substring($name.Length + 3)
    $path = Join-Path $folder.FullName 'grid.xml'
    [xml]$grid = Get-Content -Raw $path
    $root = $grid.DocumentElement
    $root.SelectSingleNode('GridGuid').InnerText = Get-Guid "$name/$gridName"

    # WhatsApp's backgrounds carry its own artwork.
    $background = $root.SelectSingleNode('BackgroundImage')
    if ($background) {
        [void]$root.RemoveChild($background)
        Get-ChildItem $folder.FullName -Filter 'background.*' | Remove-Item
    }

    $cells = $root.SelectSingleNode('Cells')
    foreach ($cell in @($cells.SelectNodes('Cell'))) {
        $dead = $false
        foreach ($command in @($cell.SelectNodes('Content/Commands/Command'))) {
            if ((Update-Command $command) -eq 'unanswered') { $dead = $true }
        }
        $place = "$short $([int]('0' + $cell.X)),$([int]('0' + $cell.Y))"
        if ($dead -or $place -in @($config.Blank)) {
            $caption = $cell.SelectSingleNode('Content/CaptionAndImage/Caption')
            $removedCells.Add([pscustomobject]@{ Grid = $gridName; Text = "$place '$(if ($caption) { $caption.InnerText -replace '\s+', ' ' })'" })
            [void]$cells.RemoveChild($cell)
        }
    }

    # Grid-level commands (AutoContentCommands, on-open Commands) get the same rewrite; an unanswered
    # script call there is dropped, since there is no cell to remove.
    foreach ($command in @($root.SelectNodes("*[not(self::Cells)]//Command"))) {
        if ((Update-Command $command) -eq 'unanswered') {
            $warnings.Add([pscustomobject]@{ Grid = $gridName; Text = "$short`: dropped grid-level $($command.SelectSingleNode('Parameter').InnerText)" })
            [void]$command.ParentNode.RemoveChild($command)
        }
    }

    # Edits keep a stock cell's caption, image and style: Commands replaces its commands, Prepend and Append add
    # before or after its own, JumpBack turns its Jump.To into Jump.Back (back to whichever grid opened this
    # one), and Span = @(columns, rows) resizes it.
    foreach ($edit in @($config.Edits | Where-Object { $_.Grid -eq $short })) {
        $target = Get-CellAt $cells $edit.X $edit.Y
        if (-not $target) { throw "No cell at $short $($edit.X),$($edit.Y) to edit." }
        $list = $target.SelectSingleNode('Content/Commands')
        if (-not $list) { $list = $target.SelectSingleNode('Content').PrependChild($grid.CreateElement('Commands')) }
        if ($edit.Commands) { $list.RemoveAll() }
        foreach ($command in @($edit.Commands) + @($edit.Append) | Where-Object { $_ }) {
            $node = $list.AppendChild($grid.CreateElement('Command'))
            $node.SetAttribute('ID', $command.ID)
            foreach ($key in @($command.Keys | Where-Object { $_ -ne 'ID' } | Sort-Object)) {
                $parameter = $node.AppendChild($grid.CreateElement('Parameter'))
                $parameter.SetAttribute('Key', $key)
                $parameter.InnerText = $command[$key]
            }
        }
        if ($edit.Span) {
            foreach ($pair in @(@('ColumnSpan', $edit.Span[0]), @('RowSpan', $edit.Span[1]))) {
                if ($pair[1] -le 1) { $target.RemoveAttribute($pair[0]) } else { $target.SetAttribute($pair[0], "$($pair[1])") }
            }
        }
        $first = $list.FirstChild
        foreach ($command in @($edit.Prepend | Where-Object { $_ })) {
            $node = $grid.CreateElement('Command')
            $node.SetAttribute('ID', $command.ID)
            foreach ($key in @($command.Keys | Where-Object { $_ -ne 'ID' } | Sort-Object)) {
                $parameter = $node.AppendChild($grid.CreateElement('Parameter'))
                $parameter.SetAttribute('Key', $key)
                $parameter.InnerText = $command[$key]
            }
            [void]$list.InsertBefore($node, $first)
        }
        if ($edit.JumpBack) {
            foreach ($jump in @($list.SelectNodes("Command[@ID='Jump.To']"))) {
                $back = $grid.CreateElement('Command'); $back.SetAttribute('ID', 'Jump.Back')
                [void]$list.ReplaceChild($back, $jump)
            }
        }
    }

    foreach ($spec in @($config.Cells | Where-Object { $_.Grid -eq $short })) {
        $old = Get-CellAt $cells $spec.X $spec.Y
        if ($old) { [void]$cells.RemoveChild($old) }
        [void]$cells.AppendChild((New-Cell $grid $spec))
    }

    if ($gridName -eq $startGrid) {
        $logo = Get-CellAt $cells $template.LogoCell[0] $template.LogoCell[1]
        $image = $logo.SelectSingleNode('Content/CaptionAndImage/Image')
        $image.InnerText = '.png'
        $stem = "$($template.LogoCell[0])-$($template.LogoCell[1])"
        Get-ChildItem $folder.FullName -Filter "$stem.*" | Remove-Item
        Copy-Item (Join-Path $siteDir $config.Logo) (Join-Path $folder.FullName "$stem.png")
        # AutoStart runs the Start cell's commands when the grid opens, so no Start press is needed.
        $startCell = $cells.SelectSingleNode("Cell[Content/CaptionAndImage/Caption='Start']")
        # The Start cell jumps to Home, then navigates, so Home's loader runs on a blank page. Wait for the site
        # to load, then run the loader there (seen on a fresh machine 2026-11-06: no script cell worked).
        if ($startCell -and $config.StartWait) {
            $list = $startCell.SelectSingleNode('Content/Commands')
            $wait = $list.AppendChild($grid.CreateElement('Command')); $wait.SetAttribute('ID', 'CommandExecution.Wait')
            $p1 = $wait.AppendChild($grid.CreateElement('Parameter')); $p1.SetAttribute('Key', 'waittime'); $p1.InnerText = [TimeSpan]::FromSeconds($config.StartWait).ToString('hh\:mm\:ss\.fffffff')
            $p2 = $wait.AppendChild($grid.CreateElement('Parameter')); $p2.SetAttribute('Key', 'cancellable'); $p2.InnerText = '1'
            $load = $list.AppendChild($grid.CreateElement('Command')); $load.SetAttribute('ID', 'WebBrowser.ExecuteJavaScript')
            $p3 = $load.AppendChild($grid.CreateElement('Parameter')); $p3.SetAttribute('Key', 'commandid'); $p3.InnerText = "$scriptName/Load"
        }
        $existing = $root.SelectSingleNode('Commands')
        if ($existing) { [void]$root.RemoveChild($existing) }
        if ($config.AutoStart) {
            if (-not $startCell) { throw "No Start cell on $startGrid for AutoStart." }
            [void]$root.InsertAfter($startCell.SelectSingleNode('Content/Commands').CloneNode($true), $root.SelectSingleNode('RowDefinitions'))
        }
    }

    $calls = @($grid.SelectNodes("//Command[@ID='WebBrowser.ExecuteJavaScript' or @ID='WebBrowser.SpeakJavascriptFunction']/Parameter[@Key='commandid']"))
    foreach ($parameter in $calls) {
        if ($parameter.InnerText -notmatch "^$([regex]::Escape($scriptName))/(.+)$") { throw "$short`: unexpected commandid $($parameter.InnerText)" }
        $parameter.InnerText = if ($Matches[1] -eq 'Load') { $loaderId } else { Get-CallId $Matches[1] }
    }
    if ($calls.Count) {
        $onOpen = $root.SelectSingleNode('Commands')
        if (-not $onOpen) { $onOpen = $root.InsertAfter($grid.CreateElement('Commands'), $root.SelectSingleNode('RowDefinitions')) }
        $load = $onOpen.AppendChild($grid.CreateElement('Command')); $load.SetAttribute('ID', 'WebBrowser.ExecuteJavaScript')
        $parameter = $load.AppendChild($grid.CreateElement('Parameter')); $parameter.SetAttribute('Key', 'commandid'); $parameter.InnerText = $loaderId
    }

    # ScanBlocks: a switch user scans group by group (ScanBlock 1 first). Cells not listed stay in group 1.
    $groups = if ($config.ScanBlocks) { $config.ScanBlocks[$short] } else { $null }
    foreach ($place in @(if ($groups) { $groups.Keys })) {
        $xy = $place -split ','
        $target = Get-CellAt $cells ([int]$xy[0]) ([int]$xy[1])
        if (-not $target) { throw "No cell at $short $place for ScanBlocks." }
        $target.SetAttribute('ScanBlock', "$($groups[$place])")
    }

    $jumps[$gridName] = @($grid.SelectNodes("//Command[@ID='Jump.To']/Parameter[@Key='grid']") | ForEach-Object { $_.InnerText })
    Save-Xml $grid $path
    if ($folder.Name -ne $gridName) { Rename-Item $folder.FullName $gridName }
}

# Keep only grids reachable from the Start grid by Jump.To.
$reached = [Collections.Generic.HashSet[string]]::new()
$queue = [Collections.Generic.Queue[string]]::new()
$queue.Enqueue($startGrid)
while ($queue.Count) {
    $next = $queue.Dequeue()
    if (-not $reached.Add($next)) { continue }
    foreach ($target in $jumps[$next]) { $queue.Enqueue($target) }
}
$droppedGrids = @($jumps.Keys | Where-Object { -not $reached.Contains($_) } | Sort-Object)
foreach ($dropName in $droppedGrids) { Remove-Item -Recurse (Join-Path $gridsDir $dropName) }

# Settings: start grid, description, thumbnail. Smartbox's documentation and versioning ids are dropped,
# so Grid 3 does not treat this set as its own WhatsApp or YouTube set.
$settingsPath = Join-Path $work 'Settings0\settings.xml'
$root = $stockSettings.DocumentElement
$root.StartGrid = $startGrid
$root.Description = $config.Description
$root.ThumbnailBackground = $config.ThumbnailBackground
$root.Thumbnail = '.png'
foreach ($drop in 'DocumentationSlug', 'DocumentationUrl', 'LocalEditorId', 'VersioningId') {
    $node = $root.SelectSingleNode($drop)
    if ($node) { [void]$root.RemoveChild($node) }
}
Save-Xml $stockSettings $settingsPath
Get-ChildItem (Join-Path $work 'Settings0') -Filter 'thumbnail.*' | Remove-Item
Copy-Item (Join-Path $siteDir $config.Logo) (Join-Path $work 'Settings0\thumbnail.png')

# The page script. Grid 3 reads <Code>.js</Code> as Settings0\WebBrowser\code.js (seen in its Storage DLL).
$webDir = Join-Path $work 'Settings0\WebBrowser'
New-Item -ItemType Directory -Force $webDir | Out-Null
[IO.File]::WriteAllText((Join-Path $webDir 'webbrowserextensions.xml'), "<WebBrowserExtensions xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">`r`n  <Code>.js</Code>`r`n  <Extensions />`r`n</WebBrowserExtensions>", [Text.UTF8Encoding]::new($true))
[IO.File]::WriteAllText((Join-Path $webDir 'code.js'), $pageScript, [Text.UTF8Encoding]::new($false))

# FileMap: each XML file with the other files in its folder, as the stock sets list them.
$statics = @(Get-ChildItem $work -Recurse -File | Where-Object { $_.Name -in 'grid.xml', 'settings.xml', 'webbrowserextensions.xml' })
$map = [Text.StringBuilder]::new("<FileMap xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">`r`n  <Entries>`r`n")
foreach ($static in $statics) {
    $relative = [IO.Path]::GetRelativePath($work, $static.FullName)
    [void]$map.Append("    <Entry StaticFile=`"$relative`">`r`n      <DynamicFiles>`r`n")
    foreach ($file in @(Get-ChildItem $static.DirectoryName -File | Where-Object { $_.FullName -ne $static.FullName -and $_.Extension -ne '.xml' })) {
        [void]$map.Append("        <File>$([IO.Path]::GetRelativePath($work, $file.FullName))</File>`r`n")
    }
    [void]$map.Append("      </DynamicFiles>`r`n    </Entry>`r`n")
}
[void]$map.Append("  </Entries>`r`n</FileMap>")
[IO.File]::WriteAllText((Join-Path $work 'FileMap.xml'), $map.ToString(), [Text.UTF8Encoding]::new($true))

$output = Join-Path $repo "grids\$($config.Output)"
New-Item -ItemType Directory -Force (Split-Path $output) | Out-Null
if (Test-Path $output) { Remove-Item $output }
[IO.Compression.ZipFile]::CreateFromDirectory($work, $output)
Remove-Item -Recurse $work

Write-Output "Built: $output"
Write-Output "Grids kept: $($reached.Count). Grids dropped: $($droppedGrids.Count)."
$shown = @($removedCells | Where-Object { $reached.Contains($_.Grid) })
Write-Output "Cells removed from kept grids ($($shown.Count)): page.js does not answer their commandid, or the site blanks them."
$shown | ForEach-Object { "  $($_.Text)" }
$warnings | Where-Object { $reached.Contains($_.Grid) } | ForEach-Object { Write-Warning $_.Text }
