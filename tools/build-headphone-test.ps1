# Builds grids\Headphone Test.gridset. Each cell's caption names the device it should play on:
# the audio feedback voice (headphones) or the speaking voice (main speaker). Import it, press each cell, listen.
# Cell 3 runs templates\headphone.js on example.com, the route a site grid set can use for long text. Cell 5 is
# Grid 3's own link cursor, which should speak each link in the headphones.
# Device, Email and Texts pages use Grid 3's own "Change audio device" auto-content cells. Each one names a device
# and moves the speaking voice to it; the cell's own commands (a test sentence, Email.Speak, Sms.Speak) run as well.
# A stored internal.changeaudiodeviceautocontentcell command does not work: Grid 3 casts its text parameter to a
# device object (3.0.104, read 2026-11-09). The speaking voice stays on the last device pressed.
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
# Grid 3 fills these cells in order with its audio devices and shows each device's name.
function DeviceCell($x, $y, $commands) {
    "<Cell X=`"$x`" Y=`"$y`"><Content><Commands>$($commands -join '')</Commands><ContentType>AutoContent</ContentType>" +
    "<ContentSubType>Speech.ChangeAudioDeviceAutoContent</ContentSubType><Style><BasedOnStyle>Default</BasedOnStyle></Style></Content></Cell>"
}
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
    $(if (($cells -join '') -match 'ChangeAudioDeviceAutoContent') { '<AutoContentCommands><AutoContentCommandCollection AutoContentType="Speech.ChangeAudioDeviceAutoContent"><Commands><Command ID="AutoContent.Activate"><Parameter Key="autocontenttype">Speech.ChangeAudioDeviceAutoContent</Parameter></Command></Commands></AutoContentCommandCollection></AutoContentCommands>' } else { '<AutoContentCommands />' }) +
    "<Cells>$($cells -join '')</Cells></Grid>"
}

$homeGrid = "$name - Home"
$deviceGrid = "$name - Devices"
$webGrid = "$name - Web"
$emailGrid = "$name - Email"
$textGrid = "$name - Texts"
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
        Cell 1 2 'Device test' @("<Command ID=`"Jump.To`">$(Param 'grid' $deviceGrid)</Command>")
        Cell 2 2 'Email test' @("<Command ID=`"Jump.To`">$(Param 'grid' $emailGrid)</Command>")
        Cell 3 2 'Text message test' @("<Command ID=`"Jump.To`">$(Param 'grid' $textGrid)</Command>")
        # Sign-in checks for web mail and texts in Grid 3's browser. A person signs in; agents never enter passwords.
        (WebCell 0 1 'Gmail sign-in' 'https://mail.google.com/')
        (WebCell 1 1 'Outlook sign-in' 'https://outlook.live.com/mail/')
        (WebCell 2 1 'Google Messages' 'https://messages.google.com/web')
        # Jump.Home only reaches this set's own start grid; Grid Explorer is the way out of the set.
        Cell 3 0 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
    )
    $deviceGrid = Grid $deviceGrid 6 3 @(
        foreach ($i in 0..3) { DeviceCell $i 0 @(SpeakNow 'Test fifteen. This should play on the device this cell names.' 0) }
        Cell 4 0 'Stop speaking' @('<Command ID="Speech.Stop" />')
        Cell 5 0 'Back' @('<Command ID="Jump.Back" />')
        Cell 0 2 '16 Audio feedback (headphones)' @(SpeakNow 'Test sixteen. This is the audio feedback voice.' 1)
        Cell 5 2 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
    )
    # Press the device cell that names the headphones to hear the email there. Speech stays on that device until
    # a cell naming the speaker is pressed (here or on the Devices page).
    $emailGrid = Grid $emailGrid 6 4 @(
        '<Cell ColumnSpan="4" RowSpan="3"><Content><ContentType>LiveCell</ContentType><ContentSubType>Email.Messages</ContentSubType>' +
            '<Style><BasedOnStyle>Default</BasedOnStyle></Style></Content></Cell>'
        Cell 4 0 'Previous email' @('<Command ID="Email.Previous" />')
        Cell 4 1 'Next email' @('<Command ID="Email.Next" />')
        Cell 4 2 'Open email' @('<Command ID="Email.Open" />')
        Cell 5 0 'Email back' @('<Command ID="Email.Back" />')
        Cell 5 1 'Device test' @("<Command ID=`"Jump.To`">$(Param 'grid' $deviceGrid)</Command>")
        Cell 5 2 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
        foreach ($i in 0..3) { DeviceCell $i 3 @('<Command ID="Speech.Stop" />', '<Command ID="Email.Speak" />') }
        Cell 4 3 'Stop speaking' @('<Command ID="Speech.Stop" />')
        Cell 5 3 'Back' @('<Command ID="Jump.Back" />')
    )
    # Same for text messages (Sms.Speak). Needs a phone linked to Grid 3.
    $textGrid = Grid $textGrid 6 4 @(
        '<Cell ColumnSpan="4" RowSpan="3"><Content><ContentType>LiveCell</ContentType><ContentSubType>Sms.Messages</ContentSubType>' +
            '<Style><BasedOnStyle>Default</BasedOnStyle></Style></Content></Cell>'
        Cell 4 0 'Previous text' @('<Command ID="Sms.Previous" />')
        Cell 4 1 'Next text' @('<Command ID="Sms.Next" />')
        Cell 4 2 'Open text' @('<Command ID="Sms.Open" />')
        Cell 5 0 'Text back' @('<Command ID="Sms.Back" />')
        Cell 5 1 'Device test' @("<Command ID=`"Jump.To`">$(Param 'grid' $deviceGrid)</Command>")
        Cell 5 2 'Exit (Grid Explorer)' @('<Command ID="Settings.GridExplorer" />')
        foreach ($i in 0..3) { DeviceCell $i 3 @('<Command ID="Speech.Stop" />', '<Command ID="Sms.Speak" />') }
        Cell 4 3 'Stop speaking' @('<Command ID="Speech.Stop" />')
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
