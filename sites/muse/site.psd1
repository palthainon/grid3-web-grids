# Muse (muse.ai) on the messaging template (stock WhatsApp layout). Build: pwsh -NoProfile -File tools\build-site.ps1 -Site muse
@{
    Name        = 'Muse'
    Template    = 'messaging'
    ScriptName  = 'Muse'                # commandids become Muse/...; page.js registers GridCommands.Muse
    Url         = 'https://muse.ai/'
    Output      = 'Muse.gridset'
    Logo        = 'logo.png'            # Muse squiggle, drawn for this project
    ThumbnailBackground = '#FFFFFFFF'
    Include     = @('alert.js', 'headphone.js')  # templates\: chime and banner for new replies; reading into the headphones
    AutoStart   = $true                 # the user asked for no Start press
    StartWait   = 6                     # seconds after opening muse.ai before the script loads (slow device)
    Description = 'Muse (muse.ai) for Grid 3. Built from the Grid 3 WhatsApp grid set layout, with its own page script.'

    # Dark cells to match Muse's dark mode (page background #181819), at least 4.5:1 text contrast. The user
    # asked for a dimmer screen. Light text is #EDEDED, a little below white, for less glare.
    Theme = @{
        Background   = '#181819FF'
        BackColour   = @{ '#FFFFFFFF' = '#2A2A2DFF'; '#EDEEEFFF' = '#2A2A2DFF'; '#2C82C9FF' = '#1F5F99FF'; '#009688FF' = '#00695CFF'; '#25D366FF' = '#00695CFF' }
        BorderColour = @{ '#FFFFFFFF' = '#181819FF'; '#D3D3D3FF' = '#55555AFF'; '#BDBDBDFF' = '#55555AFF'; '#475577FF' = '#7F8FB3FF'; '#2C82C9FF' = '#1F5F99FF' }
        FontColour   = @{ '#000000FF' = '#EDEDEDFF'; '#242424FF' = '#EDEDEDFF'; '#475577FF' = '#DDE3F0FF'; '#009688FF' = '#7FD8CEFF'; '#FFFFFFFF' = '#EDEDEDFF' }
        Styles       = @{
            'Default'            = @{ BackColour = '#181819FF'; FontColour = '#EDEDEDFF' }
            'style 3'            = @{ FontColour = '#EDEDEDFF' }    # WhatsApp keys: no FontColour, so black
            'Workspace (import)' = @{ BackColour = '#181819FF' }    # the browser cell before the page draws
        }
    }

    # WhatsApp housekeeping calls with no Muse equivalent. They are removed; the rest of the cell stays.
    Ignore = @('Home/Show_Chat_List', 'Home/Cancel_Reply_To_Message')
    # Muse functions outside the messaging contract.
    Extra  = @('Home/Read_Selected_Message_Headphones', 'Panel/Toggle', 'Chats/Toggle', 'Chats/Select', 'Options/Read', 'Options/Option_1', 'Options/Option_2', 'Options/Option_3',
               'Places/Chat', 'Places/Search', 'Places/Feed', 'Places/Ideas', 'Places/Goals', 'Places/Library', 'Places/Settings',
               'Items/Previous', 'Items/Next', 'Items/Read', 'Items/Read_All', 'Items/Open', 'Items/Close', 'Search/Leave')

    # WhatsApp cells that only open grids for actions Muse lacks (delete, groups, log out, theme, media viewer) and WhatsApp's own help pages.
    Blank = @('More Tools 8,3', 'More Tools 9,3', 'More Tools 8,4', 'More Tools 9,4', 'More Tools 8,5', 'Home 8,5', 'Start 0,5')

    # Switch scan groups on Home: group 1 is messages (most used), 2 the chat column, 3 Back, Rest and More.
    ScanBlocks = @{
        # Keyboard: the letters, digits key and full stop are one group, scanned key by key, as on the user's
        # email keyboard. Row groups were tried on 2026-11-08; the operator asked for key by key again.
        'Keyboard' = @{ '0,3' = 2; '1,3' = 2; '2,3' = 2; '3,3' = 2; '4,3' = 2; '5,3' = 2; '6,3' = 2; '7,3' = 2; '8,3' = 2; '9,3' = 2; '0,4' = 2; '1,4' = 2; '2,4' = 2; '3,4' = 2; '4,4' = 2; '5,4' = 2; '6,4' = 2; '7,4' = 2; '8,4' = 2; '9,4' = 2; '0,5' = 2; '1,5' = 2; '2,5' = 2; '3,5' = 2; '4,5' = 2; '6,5' = 2; '7,5' = 2; '8,5' = 2; '9,5' = 2 }
        # Punctuation: group 1 the controls (rows 0 to 2), then one group per key row (review 2026-11-08).
        'Keyboard - Punctuation' = @{ '0,3' = 2; '1,3' = 2; '2,3' = 2; '3,3' = 2; '4,3' = 2; '5,3' = 2; '6,3' = 2; '7,3' = 2; '8,3' = 2; '9,3' = 2; '0,4' = 3; '1,4' = 3; '2,4' = 3; '3,4' = 3; '4,4' = 3; '5,4' = 3; '6,4' = 3; '7,4' = 3; '8,4' = 3; '9,4' = 3; '0,5' = 4; '1,5' = 4; '2,5' = 4; '3,5' = 4; '4,5' = 4; '6,5' = 4; '7,5' = 4; '8,5' = 4; '9,5' = 4 }
        # More Tools: one group per column: item controls (with Back), rail pages, then tools.
        'More Tools' = @{ '8,0' = 2; '8,1' = 2; '8,2' = 2; '8,3' = 2; '8,4' = 2; '8,5' = 2; '9,0' = 3; '9,1' = 3; '9,2' = 3; '9,3' = 3; '9,4' = 3; '9,5' = 3 }
        'Home' = @{ '0,1' = 2; '0,2' = 2; '0,3' = 2; '0,4' = 2; '0,5' = 2; '0,0' = 3; '9,0' = 3; '9,5' = 3 }
    }

    # Keyboard Back and Send: close the search box if nothing was typed, then go back to the grid that opened
    # the keyboard (More after Search, Home after Type or Reply).
    Edits = @(
        # Back at 0,0 as on the keyboards; Grid explorer (which leaves the set) goes to Back's old place.
        @{ Grid = 'More Tools'; X = 9; Y = 5; MoveTo = @(0, 0) }
        @{ Grid = 'More Tools'; X = 0; Y = 0; MoveTo = @(9, 5) }
        # Keys with only an image or a blank: words for auditory scanning, as Smartbox's own keyboards have.
        @{ Grid = 'Keyboard'; X = 4; Y = 5; Audio = 'space' }
        @{ Grid = 'Keyboard - Punctuation'; X = 4; Y = 5; Audio = 'space' }
        @{ Grid = 'Keyboard - Punctuation'; X = 8; Y = 4; Audio = 'enter' }
        @{ Grid = 'Keyboard - Punctuation'; X = 1; Y = 5; Audio = 'left' }
        @{ Grid = 'Keyboard - Punctuation'; X = 2; Y = 5; Audio = 'right' }
        @{ Grid = 'Keyboard'; X = 0; Y = 0; JumpBack = $true; Prepend = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Search/Leave' }) }
        @{ Grid = 'Keyboard'; X = 9; Y = 1; JumpBack = $true; Prepend = @() }
        # The email keyboard's Clear empties Grid 3's own editor; in a web page select all and delete instead.
        @{ Grid = 'Keyboard'; X = 0; Y = 2; Commands = @(@{ ID = 'ComputerControl.Keyboard'; keystring = '{LEFTCONTROL}a{DELETE}' }) }
        @{ Grid = 'Keyboard - Punctuation'; X = 0; Y = 2; Commands = @(@{ ID = 'ComputerControl.Keyboard'; keystring = '{LEFTCONTROL}a{DELETE}' }) }
        # As on the user's email keyboard: the third prediction is one cell wide, to make room for Fix, and the
        # space bar also supports fast typing.
        @{ Grid = 'Keyboard'; X = 6; Y = 2; Span = @(1, 1) }
        @{ Grid = 'Keyboard'; X = 4; Y = 5; Append = @(@{ ID = 'Settings.FastTypingDwell' }) }
    )

    # The keyboard follows the user's email keyboard: Smartbox's stock Email set (every Grid 3 install has it),
    # with Muse's browser in place of the email editor. Its Tools grid has Copy, Paste, Select all and cursor
    # moves. Send presses Enter; Back returns to the grid that opened the keyboard.
    Imports = @(
        @{ Source = 'C:\Program Files (x86)\Smartbox\Grid 3\Locale\en-US\gridsets\Accessible Apps\Email.gridset'
           Grids  = @{ 'Email message' = 'Keyboard'; 'Email message tools' = 'Keyboard - Tools'; 'Email message punctuation' = 'Keyboard - Punctuation' }
           Send   = @('Email message confirm')
           Back   = @('Email recipients')
           Return = @('Email message')
           DropCommands = @('Email.*', 'Action.Print', 'Action.UndoClear') }
    )

    # Column 0 of Home: Prev chat and Next chat move an outline over the chats, Select chat opens the outlined
    # chat and closes the chat panel, Chats opens or closes the chat panel, Muse panel opens or closes Muse's
    # avatar panel. Read options and Option 1-3 press the clickable items in Muse's newest message.
    Cells = @(
        # Back: opens the user's startup grid set at its start (Fast Talker here: set gridsetname to yours). Back
        # is at 0,0 on every Muse grid. Jump.Back cannot cross grid sets, and Change grid set takes no grid, so it
        # cannot return to the startup set's menu that opened Muse. Grid explorer is on More.
        @{ Grid = 'Home'; X = 0; Y = 0; Caption = 'Back'; Image = '[GRID3X]jump_back.wmf'; Style = 'style 2'
           Commands = @(@{ ID = 'Settings.ChangeGridSet'; gridsetname = 'Fast Talker' }) }
        @{ Grid = 'Home'; X = 0; Y = 3; Caption = 'Select chat'; Style = 'style 2'
           Commands = @(@{ ID = 'Speech.Stop' }, @{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Chats/Select' }) }
        @{ Grid = 'Home'; X = 0; Y = 4; Caption = 'Chats'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Chats/Toggle' }) }
        @{ Grid = 'Home'; X = 0; Y = 5; Caption = 'Muse panel'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Panel/Toggle' }) }
        # Fix (AI spelling correction), as on the user's email keyboard. Navigation's blue matches its colour there.
        @{ Grid = 'Keyboard'; X = 7; Y = 2; Caption = 'Fix'; Style = 'Navigation category style'
           Commands = @(@{ ID = 'Prediction.CorrectionTool' }) }
        # Read msg into the headphones (templates\headphone.js): the click lands silently, then NextElement speaks it
        # with the audio feedback voice. It replaced Emojis, which moved to More Tools in place of Zoom out (operator, 2026-11-06).
        @{ Grid = 'Home'; X = 9; Y = 3; Caption = 'Read in headphones'; Style = 'style 2'; Image = '[GRID3X]ear.wmf'
           Commands = @(@{ ID = 'Speech.Stop' }, @{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Home/Read_Selected_Message_Headphones' },
                        @{ ID = 'CommandExecution.Wait'; waittime = '00:00:01.0000000'; cancellable = '1' }, @{ ID = 'WebBrowser.NextElement' }) }
        @{ Grid = 'More Tools'; X = 9; Y = 2; Caption = 'Emojis'; Image = '[GRID3X]heart.wmf'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Home/Focus_Message_Input' }, @{ ID = 'Jump.To'; grid = 'Muse - Emoji' }) }
        @{ Grid = 'Home'; X = 9; Y = 2; Caption = 'Read options'; Style = 'style 2'
           Commands = @(@{ ID = 'Speech.Stop' }, @{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Options/Read' }) }
        @{ Grid = 'Home'; X = 8; Y = 4; Caption = 'Option 1'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Options/Option_1' }) }
        @{ Grid = 'Home'; X = 9; Y = 4; Caption = 'Option 2'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Options/Option_2' }) }
        @{ Grid = 'Home'; X = 8; Y = 5; Caption = 'Option 3'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Options/Option_3' }) }
        # More Tools: Muse's rail pages (right) and the items on them (left). Prev and Next item outline an item and say its first line,
        # Read item says all of it, Open item presses it, Close shuts search or settings. Search jumps to the keyboard to type.
        @{ Grid = 'More Tools'; X = 0; Y = 1; Caption = 'Prev item'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Items/Previous' }, @{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Items/Read' }) }
        @{ Grid = 'More Tools'; X = 0; Y = 2; Caption = 'Next item'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Items/Next' }, @{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Items/Read' }) }
        @{ Grid = 'More Tools'; X = 0; Y = 3; Caption = 'Read item'; Style = 'style 2'
           Commands = @(@{ ID = 'Speech.Stop' }, @{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Items/Read_All' }) }
        @{ Grid = 'More Tools'; X = 0; Y = 4; Caption = 'Open item'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Items/Open' }) }
        @{ Grid = 'More Tools'; X = 0; Y = 5; Caption = 'Close'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Items/Close' }) }
        @{ Grid = 'More Tools'; X = 8; Y = 1; Caption = 'Search'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Places/Search' }, @{ ID = 'Jump.To'; grid = 'Muse - Keyboard' }) }
        @{ Grid = 'More Tools'; X = 8; Y = 2; Caption = 'Feed'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Places/Feed' }) }
        @{ Grid = 'More Tools'; X = 8; Y = 3; Caption = 'Ideas'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Places/Ideas' }) }
        @{ Grid = 'More Tools'; X = 8; Y = 4; Caption = 'Goals'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Places/Goals' }) }
        @{ Grid = 'More Tools'; X = 8; Y = 5; Caption = 'Library'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Places/Library' }) }
        @{ Grid = 'More Tools'; X = 9; Y = 3; Caption = 'Settings'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Places/Settings' }) }
        @{ Grid = 'More Tools'; X = 9; Y = 4; Caption = 'Chat'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Places/Chat' }) }
    )
}
