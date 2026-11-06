# Media template: Grid 3's stock YouTube grid set (v3.98), read from this machine on 2026-11-05.
# Scan groups, Edits and the short-call loader work as for the messaging template (docs/templates.md).
# The builder copies the stock set and keeps its grids, cells and styles. Each Youtube/... commandid
# becomes <ScriptName>/... and must be answered by the site's page.js (see docs/templates.md).
@{
    Name        = 'Media'
    Source      = 'C:\Program Files (x86)\Smartbox\Grid 3\Locale\en-US\gridsets\Accessible Apps\YouTube.gridset'
    SourceVersion = 'v3.98'
    GridPrefix  = 'YouTube'            # stock grids are named "YouTube - <grid>"
    ScriptName  = 'Youtube'            # stock commandids start "Youtube/"
    StartGrid   = 'Launch'
    LogoCell    = @(2, 1)
    StockHosts  = @('www.youtube.com', 'youtube.com')

    Contract = @(
        'Home/Right', 'Home/Left', 'Home/Up', 'Home/Down', 'Home/Setup',
        'Generic/Select', 'Generic/Read', 'Generic/JumptoTop', 'Generic/PageSetUp', 'Generic/Search',
        'Search/Down', 'Search/Up', 'Search/PageSetUp', 'Search/ApplyFilter', 'Search/Search_Trending',
        'Player/PlayPause', 'Player/DisableAutoplay', 'Player/CloseAdsBanners', 'Player/Back'
    )
}
