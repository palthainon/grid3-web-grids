# Messaging template: Grid 3's stock WhatsApp grid set (v1.103), read from this machine on 2026-11-05.
# The builder copies the stock set and keeps its grids, cells and styles. Each WhatsApp/... commandid
# becomes <ScriptName>/... and must be answered by the site's page.js (see docs/templates.md).
# Stock Home layout (10x6): column 0 holds chat cells, columns 8 and 9 message cells, the browser fills
# columns 1-7. All Home cells are in scan group 1, so a switch scan reaches each row's chat cell first;
# a site can reorder that with ScanBlocks. The Keyboard grid's Back and Send jump to Home; a site can make
# them return to the opening grid with Edits (JumpBack). For new-message alerts, include templates\alert.js
# (Include = @('alert.js')) and call grid3Alert.watch() from page.js.
@{
    Name        = 'Messaging'
    Source      = 'C:\Program Files (x86)\Smartbox\Grid 3\Locale\en-US\gridsets\Accessible Apps\WhatsApp.gridset'
    SourceVersion = 'v1.103'
    GridPrefix  = 'WhatsApp'           # stock grids are named "WhatsApp - <grid>"
    ScriptName  = 'WhatsApp'           # stock commandids start "WhatsApp/"
    StartGrid   = 'Start'
    LogoCell    = @(2, 1)              # the 6x3 logo on the Start grid
    StockHosts  = @('web.whatsapp.com')

    # The commandids a messaging site's page.js can answer, from the stock set. A cell that needs a
    # commandid the site does not answer is removed, unless the site lists it under Ignore.
    Contract = @(
        'Home/Focus_Message_Input', 'Home/Read_Selected_Message', 'Home/Previous_Message', 'Home/Next_Message',
        'Home/Previous_Chat', 'Home/Next_Chat', 'Home/Read_Selected_Chat_Name', 'Home/Reply_To_Message',
        'Home/Jump_To_End_Of_Conversation', 'Home/Center_Current_Message', 'Home/Show_Chat_List',
        'Home/Cancel_Reply_To_Message', 'Home/Search', 'Home/Toggle_Theme', 'Home/Attach_Photo_Video'
    )
}
