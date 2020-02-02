@{
    RootModule = 'GPG.psm1'
    ModuleVersion = '2020.1.25.1'
    GUID = '6a29410d-7ab2-4603-a453-84ea5cb5bbcc'
    Author = 'Julian Easterling'
    PowerShellVersion = '3.0'
    TypesToProcess = @()
    FormatsToProcess = @()
    FunctionsToExport = @(
        "Invoke-GPG"
        "Get-GPGPublicKeyId"
    )
    AliasesToExport = @(
        "Invoke-GnuGP"
    )
}
