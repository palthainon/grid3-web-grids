# Muse (muse.ai) on the messaging template (stock WhatsApp layout). Build: pwsh -NoProfile -File tools\build-site.ps1 -Site muse
@{
    Name        = 'Muse'
    Template    = 'messaging'
    ScriptName  = 'Muse'                # commandids become Muse/...; page.js registers GridCommands.Muse
    Url         = 'https://muse.ai/'
    Output      = 'Muse.gridset'
    Logo        = 'logo.png'            # Muse squiggle, drawn for this project
    ThumbnailBackground = '#FFFFFFFF'
    Include     = @('alert.js')         # templates\alert.js: chime and banner for new Muse replies
    AutoStart   = $true                 # the user asked for no Start press
    StartWait   = 6                     # seconds after opening muse.ai before the script loads (slow device)
    Description = 'Muse (muse.ai) for Grid 3. Built from the Grid 3 WhatsApp grid set layout, with its own page script.'

    # WhatsApp housekeeping calls with no Muse equivalent. They are removed; the rest of the cell stays.
    Ignore = @('Home/Show_Chat_List', 'Home/Cancel_Reply_To_Message')
    # Muse functions outside the messaging contract.
    Extra  = @('Panel/Toggle', 'Chats/Toggle', 'Chats/Select', 'Options/Read', 'Options/Option_1', 'Options/Option_2', 'Options/Option_3',
               'Places/Chat', 'Places/Search', 'Places/Feed', 'Places/Ideas', 'Places/Goals', 'Places/Library', 'Places/Settings',
               'Items/Previous', 'Items/Next', 'Items/Read', 'Items/Read_All', 'Items/Open', 'Items/Close', 'Search/Leave')

    # WhatsApp cells that only open grids for actions Muse lacks (delete, groups, log out, theme, media viewer) and WhatsApp's own help pages.
    Blank = @('More Tools 8,3', 'More Tools 9,3', 'More Tools 8,4', 'More Tools 9,4', 'More Tools 8,5', 'Home 8,5', 'Start 0,5')

    # Switch scan groups on Home: group 1 is messages (most used), 2 the chat column, 3 Fast Talker, Rest and More.
    ScanBlocks = @{
        'Home' = @{ '0,1' = 2; '0,2' = 2; '0,3' = 2; '0,4' = 2; '0,5' = 2; '0,0' = 3; '9,0' = 3; '9,5' = 3 }
    }

    # Keyboard Back and Send: close the search box if nothing was typed, then go back to the grid that opened
    # the keyboard (More after Search, Home after Type or Reply).
    Edits = @(
        @{ Grid = 'Keyboard'; X = 0; Y = 0; JumpBack = $true; Prepend = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Search/Leave' }) }
        @{ Grid = 'Keyboard'; X = 9; Y = 1; JumpBack = $true; Prepend = @() }
    )

    # Column 0 of Home: Prev chat and Next chat move an outline over the chats, Select chat opens the outlined
    # chat and closes the chat panel, Chats opens or closes the chat panel, Muse panel opens or closes Muse's
    # avatar panel. Read options and Option 1-3 press the clickable items in Muse's newest message.
    Cells = @(
        # Back to the user's startup grid set (Fast Talker here: set gridsetname to yours). Grid explorer is on More.
        @{ Grid = 'Home'; X = 0; Y = 0; Caption = 'Fast Talker'; Style = 'style 2'
           Commands = @(@{ ID = 'Settings.ChangeGridSet'; gridsetname = 'Fast Talker' }) }
        @{ Grid = 'Home'; X = 0; Y = 3; Caption = 'Select chat'; Style = 'style 2'
           Commands = @(@{ ID = 'Speech.Stop' }, @{ ID = 'WebBrowser.SpeakJavascriptFunction'; commandid = 'Muse/Chats/Select' }) }
        @{ Grid = 'Home'; X = 0; Y = 4; Caption = 'Chats'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Chats/Toggle' }) }
        @{ Grid = 'Home'; X = 0; Y = 5; Caption = 'Muse panel'; Style = 'style 2'
           Commands = @(@{ ID = 'WebBrowser.ExecuteJavaScript'; commandid = 'Muse/Panel/Toggle' }) }
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
