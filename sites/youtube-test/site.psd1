# YouTube on the media template (stock YouTube layout), as a test of the template. Not for daily use:
# he has Smartbox's own YouTube set. Build: pwsh -NoProfile -File tools\build-site.ps1 -Site youtube-test
@{
    Name        = 'YouTube Test'
    Template    = 'media'
    ScriptName  = 'YouTubeTest'         # commandids become YouTubeTest/...; page.js registers GridCommands.YouTubeTest
    Url         = 'https://www.youtube.com/'
    Output      = 'YouTube Test.gridset'
    Logo        = 'logo.png'            # plain play symbol, drawn for this repo
    ThumbnailBackground = '#FFFFFFFF'
    AutoStart   = $false
    Description = 'Test of the media template on YouTube, with its own page script. Not for daily use.'

    # Search results filter: YouTube's own filter menu changes often; results work without it.
    Ignore = @('Search/ApplyFilter')
}
