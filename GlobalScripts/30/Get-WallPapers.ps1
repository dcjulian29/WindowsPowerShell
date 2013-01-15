function Get-WallPapers
{
  $up = "$($env:Home)\SkyDrive\Wallpapers\"
  @("http://themeserver.microsoft.com/default.aspx?p=Bing&c=Aerial&m=en-US",
    "http://themeserver.microsoft.com/default.aspx?p=Bing&c=Aerial_Imagery_of_Europe&m=en-gb",
    "http://themeserver.microsoft.com/default.aspx?p=Windows&c=Aqua&m=en-US",
    "http://themeserver.microsoft.com/default.aspx?p=Windows&c=Fauna&m=en-US",
    "http://themeserver.microsoft.com/default.aspx?p=Windows&c=Flora&m=en-US",
    "http://themeserver.microsoft.com/default.aspx?p=Windows&c=Insects&m=en-US",
    "http://themeserver.microsoft.com/default.aspx?p=Windows&c=LandScapes&m=en-US",
    "http://themeserver.microsoft.com/default.aspx?p=Windows&c=Everyday_art&m=en-US") | foreach `
    {
      $_
      Get-RssEnclosures $_ $up
    }
}
