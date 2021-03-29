function netFirewall {
    [OutputType([System.String])]
    param (
        [String]$Name,
        [ValidateSet("add","del","show")]
        [String]$Operation,
        [String]$Protocol,
        [String]$LocalPort,
        [ValidateSet("Inbound", "Outbound")]
        [String]$Direction,
        [ValidateSet("Allow", "Block", "Bypass")]
        [String]$Action
    )

    $argumentList = @('advfirewall', 'firewall', $Operation, 'rule', "name=""${Name}""")

    if ($Direction) {
        $dir = switch ($Direction) {
            "Inbound" { "in" }
            "Outbound" { "out" }
        }

        $argumentList += "dir=$dir"
    }

    if ($Protocol) {
        $argumentList += "protocol=$Protocol"
    }

    if ($LocalPort) {
        $argumentList += "localport=$LocalPort"
    }

    if ($Action) {
        $argumentList += "action=$Action"
    }

    $outputPath = "${env:TEMP}\netsh.out"

    $process = Start-Process netsh -ArgumentList $argumentList -Wait -NoNewWindow -RedirectStandardOutput $outputPath -Passthru

    if ($process.ExitCode -ne 0) {
        throw "Error Performing Operation '$Operation' For Firewall Rule"
    }

    return ((Get-Content $outputPath) -join "`n")
}

function netUrlAcl {
    [OutputType([System.String])]
    param (
        [String]$Protocol = "http",
        [ValidateSet("add","del","show")]
        [String]$Operation,
        [String]$Url,
        [String]$User
    )

    $argumentList = @($Protocol, $Operation, 'urlacl', "url=""${Url}""")

    if ($user) {
        $argumentList += "user=""${User}"""
    }

    $outputPath = "${env:TEMP}\netsh.out"

    $process = Start-Process netsh -ArgumentList $argumentList `
        -Wait -NoNewWindow -RedirectStandardOutput $outputPath -Passthru

    if ($process.ExitCode -ne 0) {
        throw "Error Performing Operation '${Operation}' For Reserved URL"
    }

    return ((Get-Content $outputPath) -join "`n")
}

function getUrl {
    param (
        [String]$Protocol = "http",
        [String]$Hostname = "*",
        [String]$Port
    )

    return "${Protocol}://${Hostname}:${Port}/"
}

#------------------------------------------------------------------------------

function Get-NetworkInterface {
    [CmdletBinding()]
    param (
        [string] $InterfaceName,
        [string] $InterfaceType,
        [string] $InterfaceStatus
    )

    $i = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

    if ($InterfaceName) {
        $i = $i | Where-Object Name -eq $InterfaceName
    }

   if ($InterfaceType) {
        $i = $i | Where-Object NetworkInterfaceType -eq $InterfaceType
    }

    if ($InterfaceStatus) {
        $i = $i | Where-Object OperationalStatus -eq $InterfaceStatus
    }

    return $i
}

function Get-NetworkIP {
    [CmdletBinding()]
    param (
        [string] $InterfaceName,
        [string] $InterfaceType,
        [string] $InterfaceStatus
    )

    $collection = Get-NetworkInterface -InterfaceName $InterfaceName `
        -InterfaceType $InterfaceType -InterfaceStatus $InterfaceStatus


    $r = @()

    foreach ($item in $collection) {
        $r += [PSCustomObject] @{
            Name = $item.Name
            IPv4 = ($item.GetIPProperties().UnicastAddresses `
                | Where-Object PrefixLength -eq 24 ).Address.IPAddressToString
            IPv6 = ($item.GetIPProperties().UnicastAddresses `
                | Where-Object PrefixLength -eq 64 ).Address.IPAddressToString
        }
    }

    return $r
}

function Get-PublicIP {
  param(
    [Switch] $IPv6
  )

  if(-not $IPv6) {
    $url = 'ipv4bot.whatismyipaddress.com'
  } else {
    $url = 'ipv6bot.whatismyipaddress.com'
  }

  Invoke-WebRequest -Uri $url -UseBasicParsing -DisableKeepAlive `
    | Select-Object -ExpandProperty Content
}

function Get-WirelessState {
    $adapter = Get-NetworkInterface -InterfaceStatus Up -InterfaceType Wireless80211

    $r = [PSCustomObject]@{
        IPv4Address = (Get-NetworkIp $adapter.Name).IPv4
        IPv6Address = (Get-NetworkIp $adapter.Name).IPv6
        SSID = ""
        BSSID = ""
        State = ""
        Authentication = ""
        Channel = ""
        Signal = ""
        RxRate = ""
        TxRate = ""
        StateTime = Get-Date
    }

    $status = ($(netsh wlan show interfaces)).Split("`n")

    foreach ($line in $status) {
        if ($line -match "^    SSID\s{10,35}:\s(.*)") { $r.SSID = $Matches[1] }
        if ($line -match "^    BSSID\s{10,35}:\s(.*)") { $r.BSSID = $Matches[1] }
        if ($line -match "^    State\s{10,35}:\s(.*)") { $r.State = $Matches[1]}
        if ($line -match "^    Authentication\s{5,35}:\s(.*)") { $r.Authentication = $Matches[1] }
        if ($line -match "^    Channel\s{10,35}:\s(.*)") { $r.Channel = $Matches[1] }
        if ($line -match "^    Signal\s{10,35}:\s(.*)") { $r.Signal=$Matches[1] }
        if ($line -match "^    Receive\srate\s\(Mbps\)\s{2,15}:\s(.*)") { $r.RxRate = $Matches[1] }
        if ($line -match "^    Transmit\srate\s\(Mbps\)\s{2,15}:\s(.*)") { $r.TxRate=$Matches[1] }
    }

    return $r
}

function Invoke-Http {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string] $Url,
        [Parameter(Mandatory=$True,Position=2)]
        [ValidateSet("GET", "POST", "HEAD")]
        [string] $Verb,
        [Parameter(Mandatory=$False,Position=3)]
        [string] $Content
    )

    $webRequest = [System.Net.WebRequest]::Create($url)
    $encodedContent = [System.Text.Encoding]::UTF8.GetBytes($content)
    $webRequest.Method = $verb.ToUpperInvariant()

    if ($encodedContent.length -gt 0) {
        $webRequest.ContentLength = $encodedContent.length
        $requestStream = $webRequest.GetRequestStream()
        $requestStream.Write($encodedContent, 0, $encodedContent.length)
        $requestStream.Close()
    }

    [System.Net.WebResponse] $resp = $webRequest.GetResponse();

    if ($resp -ne $null) {
        $rs = $resp.GetResponseStream();
        [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
        [string] $results = $sr.ReadToEnd();

        return $results
    }
}

function New-FirewallRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        [String]$Protocol,
        [String]$LocalPort,
        [ValidateSet("Inbound", "Outbound")]
        [String]$Direction,
        [ValidateSet("Allow", "Block", "Bypass")]
        [String]$Action
    )

    netFirewall -Name $Name `
        -Operation "add" `
        -Protocol $Protocol `
        -LocalPort $LocalPort `
        -Direction $Direction `
        -Action $Action
}

function New-UrlReservation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Protocol = "http",
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Hostname = "*",
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Port,
        [ValidateNotNullOrEmpty()]
        [String]$User
    )

    $url = getUrl $Protocol $Hostname $Port

    netUrlAcl -Protocol $Protocol -Operation "add" -Url $url -User $User
}

function Remove-FirewallRule {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name
    )

    netFirewall -Name $Name -Operation "del"
}

function Remove-UrlReservation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Protocol = "http",
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Hostname = "*",
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Port
    )

    $url = getUrl $Protocol $Hostname $Port

    netUrlAcl -Protocol $Protocol -Operation "del" -Url $url
}

function Show-UrlReservation {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [String]$Protocol = "http",
        [ValidateNotNullOrEmpty()]
        [String]$Hostname = "*",
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [ValidateNotNullOrEmpty()]
        [String]$User
    )

    $url = getUrl $Protocol $Hostname $Port

    netUrlAcl -Operation "show" -Url $url -User $User
}

function Show-WirelessInterface {
    netsh wlan show interfaces
}
