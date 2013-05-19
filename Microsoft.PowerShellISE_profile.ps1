# PowerShell ISE Profile Script

$globalScriptsPath = (Get-Item "$(Split-Path $profile)\PowerShellISE\")
 
Get-ChildItem -Path $globalScriptsPath -Filter *.ps1 -Recurse | % `
{
  "Loading Script: $($_.Name)"
  . $_.FullName
}

Get-ChildItem -Path $globalScriptsPath -Filter *.psm1 -Recurse | % `
{
  "Loading Module: $($_.Name)"
  Import-Module $_.FullName -Force
}

Set-Location C:\
