<#DISCLAIMER: 

The sample scripts are not supported under any Microsoft standard support program or service. 
The sample scripts are provided AS IS without warranty of any kind. 
Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. 
The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages. 

#>

<#   
.SYNOPSIS   
    DHCP Server deployment and migration script
  
.DESCRIPTION   
    Installs DHCP role to the new server if the role does not exist
    Migrates old DHCP Server to the newly deployed DHCP server

.NOTES   
    Author: Darijan Ravanan
   
#>
 
# required parameters.
# script will ask you to enter the required values.
[CmdletBinding()]
param (
    #Enter the name of the new DHCP server on which you want to migrate the dhcp role from the old one.
    [Parameter(Mandatory=$True, HelpMessage = 'Enter the name of the new DHCP server on which you want to migrate the dhcp role from the old one.')]
    [String]
    $NewDHCPServer,
    #Enter the name of the OLD DHCP server from which you want to migrate the dhcp role to the new one.
    [Parameter(Mandatory=$True, HelpMessage = 'Enter the name of the OLD DHCP server from which you want to migrate the dhcp role to the new one.')]
    [String]
    $OldDHCPServer
)
#Get domain admin credentials / Enter credentials with the following formats example: admin@company.local or company\admin
$cred = Get-Credential 

#checks if the role is installed on the new server
$getdhcp = Get-WindowsFeature -ComputerName $NewDHCPServer | Where-Object {$_.Name -eq 'DHCP' -and $_.InstallState -eq 'Available'}

#if clause
if ($getdhcp) 
        {
        #if it is not installed, do the following.
        Install-WindowsFeature -Name DHCP -ComputerName $NewDHCPServer -Credential $cred -IncludeManagementTools
        }
    
    #Backup database on the old dhcp server / Unauthorize dhcp server from AD / Stop the service.
    Invoke-Command -ComputerName $OldDHCPServer -Credential $cred -ScriptBlock {
            Backup-DhcpServer 'C:\dhcpbackup1'
            Remove-DhcpServerInDC -ErrorAction SilentlyContinue
            Stop-Service -Name DHCPServer 
        }

    #Transfering database to the new dhcp Server
    $source = "\\$OldDHCPServer\c$\dhcpbackup1\*"
    $destination = "\\$NewDHCPServer\c$\Windows\System32\dhcp\backup"
    Copy-Item -Path $source -Recurse -Destination $destination -force -Verbose

    #passing credentials in order to run Add-DHCPServerInDC (Double hop remoting).
    Invoke-Command -ComputerName $NewDHCPServer -ScriptBlock { Register-PSSessionConfiguration -Name Conn1 -RunAsCredential '' -Force } -ErrorAction Ignore
    Start-Sleep -s 5
    #Restore database on the new dhcp server / Authorize dhcp server in AD / Restart the service.
        Invoke-Command -ComputerName $NewDHCPServer -Credential $cred -ScriptBlock {
            Restore-DhcpServer 'C:\Windows\System32\dhcp\backup'
            Restart-Service -Name DHCPServer
            Add-DHCPServerInDC
            Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2
        } -ConfigurationName Conn1
    
    Write-Host 'Script finished, check you newly migrated DHCP server'
