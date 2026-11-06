# Builds grids\Headphone Test.gridset. Each cell's caption names the device it should play on:
# the audio feedback voice (headphones) or the speaking voice (main speaker). Import it, press each cell, listen.
# Cells 3 and 4 run templates\headphone.js on example.com, the route a site grid set can use for long text.
# Usage: pwsh -File tools\build-headphone-test.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
$name = 'Headphone Test'
$utf8Bom = [Text.UTF8Encoding]::new($true)

function Get-Guid($text) {
    [guid]::new([Security.Cryptography.MD5]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToString()
}
function Escape($text) { [Security.SecurityElement]::Escape($text) }
function Param($key, $value) { "<Parameter Key=`"$key`">$(Escape $value)</Parameter>" }
function SpeakNow($text, $auditory) {
    "<Command ID=`"Speech.SpeakNow`">$(Param 'text' $text)$(Param 'useauditoryvoice' $auditory)$(Param 'wait' 0)</Command>"
}
# Grid 3 runs "GridCommands." + commandid + "()" with spaces and hyphens made "_" and "/" made ".", so the
# script goes in percent-encoded (same method as build-site.ps1).
function Script($id, $source) {
    $safe = '[A-Za-z0-9!#$()*+,.:;=?@\[\]^_`{|}~]'
    $encoded = -join ([Text.Encoding]::UTF8.GetBytes($source) | ForEach-Object {
        $c = [char]$_; if ($_ -lt 128 -and "$c" -cmatch $safe) { $c } else { '%{0:X2}' -f $_ } })
    $call = "_;function`tGridCommands(){};GridCommands._=function(){return(0,eval)(decodeURIComponent('$encoded'))};GridCommands._"
    "<Command ID=`"WebBrowser.$id`">$(Param 'commandid' $call)</Command>"
}
function Cell($x, $y, $caption, $commands) {
    "<Cell X=`"$x`" Y=`"$y`"><Content><Commands>$($commands -join '')</Commands>" +
    "<CaptionAndImage><Caption>$(Escape $caption)</Caption></CaptionAndImage>" +
    "<Style><BasedOnStyle>Default</BasedOnStyle></Style></Content></Cell>"
}
function Grid($gridName, $columns, $rows, $cells) {
    "<Grid xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`"><BackgroundColour>#D6DBD8FF</BackgroundColour>" +
    "<GridGuid>$(Get-Guid "$name/$gridName")</GridGuid>" +
    "<ColumnDefinitions>$('<ColumnDefinition />' * $columns)</ColumnDefinitions>" +
    "<RowDefinitions>$('<RowDefinition />' * $rows)</RowDefinitions>" +
    "<AutoContentCommands /><Cells>$($cells -join '')</Cells></Grid>"
}

$homeGrid = "$name - Home"
$webGrid = "$name - Web"
$headphone = Get-Content (Join-Path $root 'templates\headphone.js') -Raw
$web3 = 'Test three. If you hear this in your headphones, a web page can read long text to you privately.'
$web4 = 'Test four. This web text should come from the main speaker.'
$grids = [ordered]@{
    $homeGrid = Grid $homeGrid 4 3 @(
        Cell 0 0 '1 Headphones' @(SpeakNow 'Test one. You should hear this in your headphones only.' 1)
        Cell 1 0 '2 Speaker' @(SpeakNow 'Test two. This should come from the main speaker.' 0)
        # Stock Start cells jump, then navigate, then wait for the page (see docs/grid3-internals.md).
        Cell 2 0 'Web test' @("<Command ID=`"Jump.To`">$(Param 'grid' $webGrid)</Command>",
            "<Command ID=`"WebBrowser.NavigateUrl`">$(Param 'url' 'https://example.com/')</Command>",
            "<Command ID=`"CommandExecution.Wait`">$(Param 'waittime' '00:00:04.0000000')$(Param 'cancellable' 1)</Command>")
        Cell 0 2 'Stop speaking' @('<Command ID="Speech.Stop" />')
        Cell 3 2 'Grid Explorer' @('<Command ID="Settings.GridExplorer" />')
    )
    $webGrid = Grid $webGrid 4 4 @(
        '<Cell ColumnSpan="4" RowSpan="3"><Content><ContentType>Workspace</ContentType><ContentSubType>WebBrowser</ContentSubType>' +
            '<Style><BasedOnStyle>Default</BasedOnStyle></Style></Content></Cell>'
        Cell 0 3 '3 Web headphones' @(Script 'ExecuteJavaScript' "$headphone`ngrid3HeadphoneSay('$web3')")
        Cell 1 3 '4 Web speaker' @(Script 'SpeakJavascriptFunction' "'$web4'")
        Cell 2 3 'Stop speaking' @('<Command ID="Speech.Stop" />')
        Cell 3 3 'Back' @('<Command ID="Jump.Back" />')
    )
}


$work = Join-Path ([IO.Path]::GetTempPath()) "headphone-test-$PID"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
$map = New-Object Text.StringBuilder '<FileMap xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Entries>'
foreach ($gridName in $grids.Keys) {
    $dir = New-Item -ItemType Directory -Force (Join-Path $work "Grids\$gridName")
    [IO.File]::WriteAllText((Join-Path $dir 'grid.xml'), ([xml]$grids[$gridName]).OuterXml, $utf8Bom)
    [void]$map.Append("<Entry StaticFile=`"Grids\$gridName\grid.xml`"><DynamicFiles /></Entry>")
}
$settingsDir = New-Item -ItemType Directory -Force (Join-Path $work 'Settings0')
[IO.File]::WriteAllText((Join-Path $settingsDir 'settings.xml'),
    '<GridSetSettings xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Appearance />' +
    "<StartGrid>$homeGrid</StartGrid><Description>Shows which device each Grid 3 speak route plays on.</Description>" +
    '<Language>en-US</Language><ShowSymbols>0</ShowSymbols><GridSetFileFormatVersion>1</GridSetFileFormatVersion></GridSetSettings>', $utf8Bom)
[void]$map.Append('<Entry StaticFile="Settings0\settings.xml"><DynamicFiles /></Entry></Entries></FileMap>')
[IO.File]::WriteAllText((Join-Path $work 'FileMap.xml'), $map.ToString(), $utf8Bom)

$output = Join-Path $root "grids\$name.gridset"
if (Test-Path $output) { Remove-Item $output }
[IO.Compression.ZipFile]::CreateFromDirectory($work, $output)
Remove-Item $work -Recurse -Force
"Built $output"
