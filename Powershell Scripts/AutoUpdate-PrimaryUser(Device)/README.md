# Intune Set Primary User Script

## Overview

This PowerShell script is designed to manage the assignment of the primary user on devices managed by Microsoft Intune. It is particularly useful when devices are migrated from Microsoft Endpoint Configuration Manager (MECM) to Intune, or when an Intune-managed device is repurposed for a new user. Since Intune does not automatically update the primary user, this script fills that gap by analyzing user sign-in logs to determine the most frequent user of each device over the last 30 days and sets that user as the primary.

## Features

- Retrieves Azure sign-in logs for Windows devices.
- Determines the most frequent user based on logins over the past 30 days.
- Sets the determined user as the primary user on the respective Intune-managed device.
- Supports both manual execution and automation within Azure Automation environments.
- Allows for testing changes without applying them via the "Test" mode.

## Requirements

- PowerShell 5.1 or higher.
- Microsoft.Graph.Authentication module.
- Microsoft.Graph.DeviceManagement module.
- Microsoft.Graph.Reports module.

## Installation

Before running the script, ensure you have the required modules installed. You can install these using PowerShellGet:

```powershell
Install-Module Microsoft.Graph.Authentication
Install-Module Microsoft.Graph.DeviceManagement
Install-Module Microsoft.Graph.Reports
```

## Configuration

Before executing the script, please configure the following parameters as per your environment:

- **EnrollmentAccounts**: Specify any enrollment accounts that should be excluded from being set as the primary user.
- **ExecutionMode**: Set to "Test" for a dry run without applying changes, or "Prod" to apply changes.
- **VerbosePreference**: Configure verbose output settings to either display messages or silently continue.

## Usage

To run the script manually:

```powershell
.\Intune-Set-PrimaryUser.ps1
```
For automated execution in an Azure Automation environment, set **$AzureAutomation** to **$True.**

## Contributing

Contributions to enhance the functionality or efficiency of this script are welcome. Please ensure to test any changes in your environment before submitting a pull request.

