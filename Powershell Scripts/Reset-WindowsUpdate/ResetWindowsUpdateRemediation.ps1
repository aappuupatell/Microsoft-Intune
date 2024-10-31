# Script authored by Arpankumar Patel
# GitHub Profile: https://github.com/aappuupatell
# Repository URL: https://github.com/aappuupatell/Microsoft-Intune
# Date modified: 2024-10-31

<#
Version: 1.0
Script: ResetWindowsUpdateDetection.ps1
Description: This script is used to reset the Windows Update detection.
#> 
$DependentService = Get-Service -name cryptsvc -DependentServices | Where-Object status -eq Started
if ($DependentService) {Stop-Service $DependentService -Force} 
Stop-Service -Name wuauserv 
Stop-Service -Name cryptsvc -Force
Stop-Service -Name bits -Force

if (Test-Path $Env:Windir\SoftwareDistribution.bak) {
    Remove-Item $Env:Windir\SoftwareDistribution.bak -Recurse -Force
    Rename-Item -Path $Env:Windir\SoftwareDistribution -NewName SoftwareDistribution.bak
} else {
    Rename-Item -Path $Env:Windir\SoftwareDistribution -NewName SoftwareDistribution.bak
}

if (Test-Path $Env:Windir\System32\catroot2.bak) {
    Remove-Item $Env:Windir\System32\catroot2.bak -Recurse -Force
    Rename-Item -Path $Env:Windir\System32\catroot2 -NewName catroot2.bak
} else {
    Rename-Item -Path $Env:Windir\System32\catroot2 -NewName catroot2.bak
}

Start-Service -Name cryptsvc 
Start-Service -Name bits 
Start-Service -Name wuauserv 
if ($DependentService) {Start-Service $DependentService}

wuauclt /updatenow
Exit 0
