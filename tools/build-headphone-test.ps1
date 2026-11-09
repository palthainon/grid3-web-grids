# Builds grids\Headphone Test.gridset. Each cell's caption names the device it should play on:
# the audio feedback voice (headphones) or the speaking voice (main speaker). Import it, press each cell, listen.
# Cell 3 runs templates\headphone.js on example.com, the route a site grid set can use for long text. Cell 5 is
# Grid 3's own link cursor, which should speak each link in the headphones.
# The Switch page moves the speaking voice to -Headphones, speaks, then back to -Speaker (Grid 3 device names,
# as listed in Settings > Speech). Grid 3 reads the device when speech starts, so the switch back waits -SwitchWait.
# The Email page does the same around Email.Speak (needs an email account in Grid 3). Cell 11 does it around
# Speech.SpeakClipboard, so any long text you copy (an email in a web browser) tests the route without an account.
# Usage: pwsh -File tools\build-headphone-test.ps1 [-Speaker '<name>'] [-Headphones '<name>'] [-SwitchWait '00:00:03']
param(
    [string]$Speaker = 'Speakers (Realtek(R) Audio)',
    [string]$Headphones = 'Headset Earphone (Poly Blackwire 3310 Series)',
    [string]$SwitchWait = '00:00:01.5000000'
)
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
# Grid 3's audio-device auto-content command, usable in a plain cell: it sets the speaking voice's device and saves the user.
function Device($device) { "<Command ID=`"internal.changeaudiodeviceautocontentcell`">$(Param 'indicatorenabled' 0)$(Param 'audio device' $device)</Command>" }
function Pause($time) { "<Command ID=`"CommandExecution.Wait`">$(Param 'waittime' $time)$(Param 'cancellable' 0)</Command>" }
function WebCell($x, $y, $caption, $url) {
    Cell $x $y $caption @("<Command ID=`"Jump.To`">$(Param 'grid' $webGrid)</Command>", "<Command ID=`"WebBrowser.NavigateUrl`">$(Param 'url' $url)</Command>")
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
$switchGrid = "$name - Switch"
$webGrid = "$name - Web"
$emailGrid = "$name - Email"
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
        Cell 1 2 'Switch test' @("<Command ID=`"Jump.To`">$(Param 'grid' $switchGrid)</Command>")
        Cell 2 2 'Email test' @("<Command ID=`"Jump.To`">$(Param 'grid' $emailGrid)</Command>")
        # Sign-in checks for web mail and texts in Grid 3's browser. A person signs in; agents never enter passwords.
        (WebCell 0 1 'Gmail sign-in' 'https://mail.google.com/')
        (WebCell 1 1 'Outlook sign-in' 'https://outlook.live.com/mail/')
        (WebCell 2 1 'Google Messages' 'https://messages.google.com/web')
        # Jump.Home only reaches this set's own start grid; Grid Explorer is the way out of the set.
        Cell 3 0 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
    )
    $switchGrid = Grid $switchGrid 4 3 @(
        Cell 0 0 '6 Switch read (headphones)' @((Device $Headphones), (SpeakNow 'Test six. This uses the speaking voice, moved to your headphones for this reading only.' 0), (Pause $SwitchWait), (Device $Speaker))
        Cell 1 0 '7 Long switch read (headphones)' @((Device $Headphones), (SpeakNow 'Test seven, part one. This long text checks whether Grid 3 keeps a long reading in the headphones after it switches back. Part two. If you hear this part on the main speaker, Grid 3 chose the device again for each piece of text. Part three. The email and text message readings are long, so this matters. Part four. Last part. If all four parts were in the headphones, the switch cell works for long messages.' 0), (Pause $SwitchWait), (Device $Speaker))
        Cell 2 0 '8 Speaker check' @(SpeakNow 'Test eight. After a switch reading, this should come from the main speaker.' 0)
        Cell 3 0 'Stop speaking' @('<Command ID="Speech.Stop" />')
        Cell 0 2 'Reset to speaker' @((Device $Speaker), (SpeakNow 'Speech is on the main speaker.' 0))
        Cell 2 2 'Back' @('<Command ID="Jump.Back" />')
        Cell 3 2 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
    )
    # Email.Speak and Speech.SpeakClipboard return at once (blockUntilSpeechStopped false), so the switch back runs
    # during the reading. Grid 3 sets the device once per text piece, so the rest stays in the headphones.
    $emailGrid = Grid $emailGrid 6 4 @(
        '<Cell ColumnSpan="4" RowSpan="3"><Content><ContentType>LiveCell</ContentType><ContentSubType>Email.Messages</ContentSubType>' +
            '<Style><BasedOnStyle>Default</BasedOnStyle></Style></Content></Cell>'
        Cell 4 0 'Previous email' @('<Command ID="Email.Previous" />')
        Cell 4 1 'Next email' @('<Command ID="Email.Next" />')
        Cell 4 2 'Open email' @('<Command ID="Email.Open" />')
        Cell 5 0 'Email back' @('<Command ID="Email.Back" />')
        Cell 5 1 'Reset to speaker' @((Device $Speaker), (SpeakNow 'Speech is on the main speaker.' 0))
        Cell 5 2 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
        Cell 0 3 '9 Read email in headphones' @('<Command ID="Speech.Stop" />', (Device $Headphones), '<Command ID="Email.Speak" />', (Pause $SwitchWait), (Device $Speaker))
        Cell 1 3 '10 Read email on speaker' @('<Command ID="Email.Speak" />')
        Cell 2 3 '11 Read copied text in headphones' @('<Command ID="Speech.Stop" />', (Device $Headphones), '<Command ID="Speech.SpeakClipboard" />', (Pause $SwitchWait), (Device $Speaker))
        Cell 3 3 'Stop speaking' @('<Command ID="Speech.Stop" />')
        Cell 4 3 '12 Speaker check' @(SpeakNow 'Test twelve. This should come from the main speaker.' 0)
        Cell 5 3 'Back' @('<Command ID="Jump.Back" />')
    )
    $webGrid = Grid $webGrid 6 4 @(
        '<Cell ColumnSpan="6" RowSpan="3"><Content><ContentType>Workspace</ContentType><ContentSubType>WebBrowser</ContentSubType>' +
            '<Style><BasedOnStyle>Default</BasedOnStyle></Style></Content></Cell>'
        # The click is async in Grid 3 (onDomClick message), so wait before NextElement moves on from it.
        Cell 0 3 '3 Web headphones' @((Script 'ExecuteJavaScript' "$headphone`ngrid3HeadphoneSay('$web3')"),
            "<Command ID=`"CommandExecution.Wait`">$(Param 'waittime' '00:00:01.0000000')$(Param 'cancellable' 1)</Command>",
            '<Command ID="WebBrowser.NextElement" />')
        Cell 1 3 '4 Web speaker' @(Script 'SpeakJavascriptFunction' "'$web4'")
        Cell 2 3 '5 Next link (headphones)' @('<Command ID="WebBrowser.NextElement" />')
        Cell 3 3 'Stop speaking' @('<Command ID="Speech.Stop" />')
        Cell 4 3 'Back' @('<Command ID="Jump.Back" />')
        Cell 5 3 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
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
