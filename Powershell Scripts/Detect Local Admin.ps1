<#
.SYNOPSIS
   Script to detect and list members of the local Administrators group on a device.
.DESCRIPTION
   This script checks the local Administrators group on a device and lists all members.
   The script outputs the members and provides a clear format for exporting results via Intune Proactive Remediations.
.NOTES
   Filename: Detect-LocalAdminGroupMembers.ps1
   Version: 1.0
   Author: Kumar Patek (OKE22651) 
#>
# Get the members of the local Administrators group
$groupName = "Administrators"
$adminGroup = [ADSI]"WinNT://./$groupName,group"
$members = @()
foreach ($member in $adminGroup.Invoke("Members")) {
   $members += $member.GetType().InvokeMember("Name", 'GetProperty', $null, $member, $null)
}
if ($members.Count -gt 0) {
   # Output each member in the Administrators group
   Write-Output "Local Administrators Group Members:"
   $members | ForEach-Object { Write-Output $_ }
   # Prepare the output for CSV export
   $membersString = $members -join ", "
   Write-Output "Members: $membersString"
   exit 0
} else {
   Write-Output "No members found in the Local Administrators group."
   exit 1
}