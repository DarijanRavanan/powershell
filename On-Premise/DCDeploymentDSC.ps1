#Script deploys additional Domain Controller to the existing forest.
#Author Darijan Ravanan.

[CmdletBinding()]
param (
    #Enter the name of the new DC server.
    [Parameter(Mandatory=$True, HelpMessage = 'Enter the name of the new DC server.')]
    [String]
    $NewDCServer,
    #Enter the name of the domain.
    [Parameter(Mandatory=$True, HelpMessage = 'Enter the name of the existing domain.')]
    [String]
    $DomainName
)
#Enter the domain admin credentials.
$Cred = Get-Credential
#Enter the safe mode credentials.
$SafeModeCred = Get-Credential
#Array of computers.
$computers = @("$NewDCServer","$env:COMPUTERNAME")
#Checking the presence of DSC Resource.
$resourceget = Get-DscResource | where-object {$_.ModuleName -like '*ActiveDirectoryDSC*'}

Foreach ($computer in $computers) {
    #if clause, Install DSCResource if its not present.
    if ($resourceget -eq $false) {
        Invoke-command -ComputerName $computer -ScriptBlock {Install-Module ActiveDirectoryDSC}
        }
}

Configuration DCDeployment {
    Import-Module ActiveDirectoryDSC
    Node $NewDCServer {
        #LCM Settings
        LocalConfigurationManager {
            RefreshMode = 'PUSH'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
        #Install ADDS
        WindowsFeature ADDSRole {
            Name = 'AD-Domain-Services'
            IncludeAllSubFeature = $true
            Ensure = 'Present'
        }
        #Create new DC
        ADDomainController NewDCDeployment {
            DomainAdministratorCredential = $Cred
            DomainName = $Domain
            SafeModeAdministratorPassword = $SafeModeCred
            DatabasePath = 'C:\Windows\NTDS'
            InstallDNS = $true
            IsGlobalCatalog = $true
            DependsOn = 'ADDSRole'
        }
    }
}
DCDeployment
Start-DSCConfiguration -Wait -Force -Verbose -Path '$PSScriptRoot\DCDeployment'
Write-Host 'Deployment finished'
