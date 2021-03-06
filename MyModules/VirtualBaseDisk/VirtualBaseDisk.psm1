function doesVhdxBlock {
    param (
        [string] $File,
        [switch] $Force
    )

    if (Test-Path $File) {
        if ($Force) {
            Remove-Item -Path $File -Force
        } else {
            Write-Warning "$File already exists, Not Overwriting..."
            return $true
        }
    }

    return $false
}

function getWIMFileName($File) {
    $wim = $File

    if (isIsoFile($File)) {
        $image = Get-DiskImage -ImagePath $File

        if (-not $image.Attached) {
            $image = Mount-DiskImage -ImagePath $image.ImagePath -Access ReadOnly

            Start-Sleep -Seconds 1
        }

        $drive = ($image | Get-Volume).DriveLetter

        $wim = "{0}:\sources\install.wim" -f $drive
    }

    return $wim
}

function isWimFile($File) {
    if ($File.EndsWith(".wim")) {
        return $true
    }
}

function isIsoFile($File) {
    if ($File.EndsWith(".iso")) {
        return $true
    }
}

###############################################################################

function Get-WindowsImagesInISO {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        [string] $IsoFile
    )

    if (isIsoFile($IsoFile)) {
        $image = Get-DiskImage -ImagePath $IsoFile

        if (-not $image.Attached) {
            $image = Mount-DiskImage -ImagePath $image.ImagePath -Access ReadOnly

            Start-Sleep -Seconds 1
        }

        $drive = ($image | Get-Volume).DriveLetter

        $wim = "{0}:\sources\install.wim" -f $drive

        if (Test-Path $wim) {
            Get-WindowsImagesInWIM $wim
        }

        $image | Dismount-DiskImage | Out-Null
    }
}

function Get-WindowsImagesInWIM {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        [string] $WimFile
    )

    if (isWimFile($WimFile)) {
        Get-WindowsImage -ImagePath $WimFile `
        | Sort-Object ImageIndex `
        | Select-Object `
            @{Label="#"; Expression={$_.ImageIndex}}, `
            @{Label="Name"; Expression={$_.ImageName}} `
        | Format-Table -AutoSize
    }
}

function New-BaseVhdxDisk {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        [string] $File,
        [string] $Index,
        [switch] $Force,
        [string] $Suffix
    )

    if ((-not (isWimFile($File))) -and (-not (isIsoFile($File)))) {
        throw "You must provide a WIM or ISO file!"
    }

    if (-not $Index) {
        if (isWimFile($File)) {
            Get-WindowsImagesInWIM -WimFile $File
        }

        if (isIsoFile($File)) {
            Get-WindowsImagesInISO -IsoFile $File
        }

        $Index = Read-Host "Enter the number for the OS you want"
    }

    if (-not $index) {
        throw "Index is required!"
    }

    $wim = getWIMFileName($File)
    $image = Get-WindowsImage -ImagePath $wim | Where-Object { $_.ImageIndex -eq $Index }

    if (-not $image) {
        throw "Image for the Index does not exist!"
    }

    $OsVersion = $image.ImageName -replace '[^0-9]'

    $vhdx = "Win{0}Base{1}.vhdx" -f $OsVersion, $Suffix

    if (doesVhdxBlock -File $vhdx -Force $Force.IsPresent) {
        return
    }

    $partition = "UEFI"

    if ($OsVersion -like "*2008*") {
        $partition = "BIOS"
    }

    Push-Location $((Get-VMHost).VirtualHardDiskPath)

    Write-Output "Creating a base disk using ""$($image.ImageName)"" to $vhdx..."

    . $PSScriptRoot\Convert-WindowsImage.ps1
    Convert-WindowsImage -SourcePath $wim -Edition $Index `
        -DiskLayout $partition  -VHDPath $vhdx `
        -VHDFormat VHDX -SizeBytes 100GB -Verbose

    Pop-Location

    if (isIsoFile($File)) {
        Get-DiskImage -ImagePath $File  Dismount-DiskImage | Out-Null
    }
}

function New-DevBaseVhdxDisk {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        [string] $File
    )

    if ((-not (isWimFile($File))) -and (-not (isIsoFile($File)))) {
        throw "You must provide a WIM or ISO file!"
    }

    $wim = getWIMFileName($File)

    $image = Get-WindowsImage -ImagePath $wim `
        | Where-Object { $_.ImageName -eq 'Windows 10 Pro' }

    if ($image) {
        $index = $image.ImageIndex
        New-BaseVhdxDisk -File $wim -Index $index -Suffix "Development" -Force
    } else {
        Write-Output "Windows 10 Pro image does not exists in that file!"
    }
}
