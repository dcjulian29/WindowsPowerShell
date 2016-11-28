﻿Function Find-UpgradableChocolateyPackages {
    Write-Host "Examining Installed Packages..."
    $installed = choco.exe list -localonly
    $available = choco.exe list


    foreach ($line in $installed) {
        if ($line -match '\d+\.\d+') {
            $package = $line.split(' ')[0]
            $output = "Checking $package... "
            Write-Host $output -NoNewline

            $localVersion = $line.Split(' ')[1]
            
            $remotePackage = $available -match "^$package\s"

            if ($remotePackage.Length -gt 0) {
                $remoteVersion = ($remotePackage).Split(' ')[1]

                if ($remoteVersion) {
                    if ($localVersion -ne $remoteVersion) {
                        Write-Host "newer version available: $remoteVersion (installed: $localVersion)" -ForegroundColor Yellow
                    } else {
                        Write-Host ("`b" * $output.length) -NoNewline
                        Write-Host (" " * $output.length) -NoNewline
                        Write-Host ("`b" * $output.length) -NoNewline
                    }
                }
            } else {
                Write-Host "remote package removed." -ForegroundColor Red
            }
        }
    }
}

Function Find-InstalledChocolateyPackages {
    $packages = (Get-ChildItem "$($env:ChocolateyInstall)\lib" | Select-Object basename).basename 
    
    $packages | ForEach-Object { $_.split('\.')[0] } | Sort-Object -unique
}

Function Find-AvailableChocolateyPackages {
    $installed = choco.exe list -localonly | ForEach-Object { $_.split(' ')[0] }
    $online = choco.exe list | ForEach-Object { $_.split(' ')[0] }
    $combined = $installed + $online | Sort-Object

    $available = $combined | Group-Object | Where-Object { $_.Count -eq 1 } | Select-Object Name

    return $available
}

Function Update-AllChocolateyPackages {
    Write-Host "Examining Installed Packages..."
    $installed = choco.exe list -localonly
    $available = choco.exe list


    foreach ($line in $installed) {
        if ($line -match '\d+\.\d+') {
            $package = $line.split(' ')[0]
            $output = "Checking $package... "
            Write-Host $output -NoNewline

            $localVersion = $line.Split(' ')[1]
            
            $remotePackage = $available -match "^$package\s"

            if ($remotePackage.Length -gt 0) {
                $remoteVersion = ($remotePackage).Split(' ')[1]

                if ($remoteVersion) {
                    if ($localVersion -ne $remoteVersion) {
                        Update-ChocolateyPackage $package
                    } else {
                        Write-Host ("`b" * $output.length) -NoNewline
                        Write-Host (" " * $output.length) -NoNewline
                        Write-Host ("`b" * $output.length) -NoNewline
                    }
                }
            } else {
                Write-Host "remote package removed." -ForegroundColor Red
            }
        }
    }
}

Function Update-ChocolateyPackage {
    Param (
        [alias("ia","installArgs")][string] $installArguments,
        [parameter(Mandatory=$true, Position=1)]
        [string] $package
    )

    if (Assert-Elevation) {
        $choco = "${env:ChocolateyInstall}\chocolateyInstall\chocolatey.ps1"

        if ($installArguments) {
            $args = " -installArguments $installArguments"
        }

        Invoke-Expression "$choco update $package$args -y"
    }
}

Function Install-ChocolateyPackage {
    Param (
        [string]$version,
        [alias("ia","installArgs")][string] $installArguments,
        [parameter(Mandatory=$true, Position=1)]
        [string] $package
    )

    if (Assert-Elevation) {
        $choco = "${env:ChocolateyInstall}\chocolateyInstall\chocolatey.ps1"

        if ($version.Length) {
            $args = $args + " -version $version"
        }

        if ($installArguments) {
            $args = $args + " -installArguments $installArguments"
        }

        Invoke-Expression "$choco install $package$args -y"
    }
}

Function Uninstall-ChocolateyPackage {
    Param (
        [string]$version,
        [alias("ia","installArgs")][string] $installArguments,
        [parameter(Mandatory=$true, Position=1)]
        [string] $package
    )

    if (Assert-Elevation) {
        $choco = "${env:ChocolateyInstall}\chocolateyInstall\chocolatey.ps1"

        if ($version) {
            $args = $args + " -version $version"
        }

        if ($installArguments) {
            $args = $args + " -installArguments $installArguments"
        }

        Invoke-Expression "$choco uninstall $package$args -y"
    }
}

Function Add-ChocolateyToPath {
    $chocolateyPath = "C:\ProgramData\chocolatey\bin"

    $path = "${env:Path};$chocolateyPath"

    $env:Path = $path
    setx.exe /m PATH $path
}

Function Purge-ObsoleteChocolateyPackages {
    $expression = "(?<name>[^\.]+)\.(?<major>\d+)\.(?<minor>\d+)\.?(?<revision>\d+)?\.?(?<patch>\d+)?"
    $packageDir = "${env:ChocolateyInstall}\lib"
    $packages = Get-ChildItem -Path $packageDir -Directory `
        | Sort-Object -Property `
            @{Expression={[RegEx]::Match($_.Name, $expression).Groups["name"].Value}}, `
            @{Expression={[int][RegEx]::Match($_.Name, $expression).Groups["major"].Value}}, `
            @{Expression={[int][RegEx]::Match($_.Name, $expression).Groups["minor"].Value}}, `
            @{Expression={[int][RegEx]::Match($_.Name, $expression).Groups["revision"].Value}}, `
            @{Expression={[int][RegEx]::Match($_.Name, $expression).Groups["patch"].Value}} `

    for ($i = 0; $i -lt $packages.Count - 1; $i++) {
        $this = $packages[$i].Name
        $next = $packages[$i + 1].Name

        $a = $this.IndexOf('.')
        $b = $next.IndexOf('.')

        $thisName = $this.Substring(0,$a)
        $nextName = $next.Substring(0,$b)

        $thisVersion = $this.Substring($a + 1)
        $nextVersion = $next.Substring($b + 1)

        if ($thisName -eq $nextName) {
            Write-Output "Purging $thisName : $thisVersion (< $nextVersion)"
            Remove-Item $packages[$i].FullName -Recurse -Force
        }
    }
}

Function Make-ChocolateyPackage {
    Param (
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        [string] $NuspecFile = "package.nuspec"
    )

    $nuget = "${env:ChocolateyInstall}\chocolateyinstall\nuget.exe"
    $options = "-Verbosity detailed -NoPackageAnalysis -NonInteractive -NoDefaultExcludes"

    Invoke-Expression "$nuget pack ""$NuspecFile"" $options"
}

###################################################################################################

Export-ModuleMember Find-UpgradableChocolateyPackages
Export-ModuleMember Find-InstalledChocolateyPackages
Export-ModuleMember Find-AvailableChocolateyPackages
Export-ModuleMember Update-AllChocolateyPackages
Export-ModuleMember Update-ChocolateyPackage
Export-ModuleMember Install-ChocolateyPackage
Export-ModuleMember Uninstall-ChocolateyPackage
Export-ModuleMember Add-ChocolateyToPath
Export-ModuleMember Purge-ObsoleteChocolateyPackages

Set-Alias chocoupdate Update-ChocolateyPackage
Export-ModuleMember -Alias chocoupdate

Export-ModuleMember Make-ChocolateyPackage

Set-Alias choco-make-package Make-ChocolateyPackage
Export-ModuleMember -Alias choco-make-package