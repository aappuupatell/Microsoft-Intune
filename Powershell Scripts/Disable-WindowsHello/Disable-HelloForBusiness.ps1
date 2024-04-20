<#
.SYNOPSIS
    Disables Windows Hello for Business for all users.
.DESCRIPTION
    By modifying the local machine's registry hive, this script disables Windows Hello for Business
    for anyone who logs into the machine. The property is controlled by the PassportForWork\Enabled
    registry key under the HKLM hive.
.NOTES
    Name    : Disable-WindowsHelloForBusiness
    Author  : @aappuupatell
    Created : 04/16/2024
    Version : 1.0
.EXAMPLE
    .\Disable-HelloForBusiness.ps1
    Disables Windows Hello for Business for all users on the local machine.
#>

# Define the registry key path
$registryKeyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork'

# Check if the registry key exists
if (Test-Path -Path $registryKeyPath) {
    # Check if the "Enabled" value exists
    if (Get-ItemProperty -Path $registryKeyPath -Name 'Enabled' -ErrorAction SilentlyContinue) {
        # Set the "Enabled" value to 0 (disabled)
        Set-ItemProperty -Path $registryKeyPath -Name 'Enabled' -Value 0 -Force
        Write-Host "Windows Hello for Business has been disabled."
    }
    else {
        # Create the "Enabled" value and set it to 0 (disabled)
        New-ItemProperty -Path $registryKeyPath -Name 'Enabled' -PropertyType DWord -Value 0 -Force
        Write-Host "Windows Hello for Business has been disabled."
    }
}
else {
    # Create the registry key and the "Enabled" value set to 0 (disabled)
    New-Item -Path $registryKeyPath -Force | Out-Null
    New-ItemProperty -Path $registryKeyPath -Name 'Enabled' -PropertyType DWord -Value 0 -Force
    Write-Host "Windows Hello for Business has been disabled."
}