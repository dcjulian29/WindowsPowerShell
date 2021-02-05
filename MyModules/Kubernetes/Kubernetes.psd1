@{
    ModuleVersion = '2102.4.1'
    GUID = 'f5af3a59-c5ad-4e26-8502-c14c3ee8d5df'
    Author = 'Julian Easterling'
    PowerShellVersion = '3.0'
    RootModule = 'Kubernetes.psm1'
    NestedModules = @(
        "k3s.psm1"
    )
    TypesToProcess = @()
    FormatsToProcess = @()
    FunctionsToExport = @(
        "Get-K3SCluster"
        "Install-K3D"
        "Open-K3SDashboard"
        "Remove-K3S"
        "Start-K3S"
        "Start-K3SDashboard"
        "Stop-K3S"
        "Test-K3D"
        "Use-K3S"
        "Use-K8SContext"
    )
    AliasesToExport = @(
        "k3s-start"
        "k3s-stop"
        "k3s-remove"
    )
}
