function Invoke-GPG {
    cmd /c $(Find-ProgramFiles GnuPG\bin\gpg.exe) $args
}

Set-Alias -Name Invoke-GnuPG -Value Invoke-GPG

function Get-GPGPublicKeyId {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Alias("File","PublicKeyFile","PublicKey")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        [string] $Path
    )

    $output = $(Invoke-GPG --dry-run --import $Path)

# gpg: armor header: Version: GnuPG v2

# gpg: pub  4096R/6C5A6003 2014-11-30  Julian Easterling <julian@julianscorner.com>
# gpg: NOTE: signature key 6C5A6003 expired 12/31/15 12:00:00 Eastern Standard Time
# gpg: key 6C5A6003: "Julian Easterling <julian@julianscorner.com>" not changed
# gpg: Total number processed: 1
# gpg:              unchanged: 1

    $output
}

function Get-PrivateKeyId {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Alias("File")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        [string] $PublicKeyFile
    )

    $output = gpg --dry-run --import pubkey.asc

# gpg: armor header: Version: GnuPG v2

# gpg: pub  4096R/6C5A6003 2014-11-30  Julian Easterling <julian@julianscorner.com>
# gpg: NOTE: signature key 6C5A6003 expired 12/31/15 12:00:00 Eastern Standard Time
# gpg: key 6C5A6003: "Julian Easterling <julian@julianscorner.com>" not changed
# gpg: Total number processed: 1
# gpg:              unchanged: 1

    $output
}
