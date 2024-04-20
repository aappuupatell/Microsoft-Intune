# Update-IntuneDeviceCategory PowerShell Script

## Overview

The Update-IntuneDeviceCategory PowerShell script is designed to facilitate the mass updating of Intune device categories through a CSV file. This script utilizes the Microsoft Graph API to perform the update operations.

## Prerequisites

Before running this script, ensure that you have:

- A Microsoft Intune subscription.
- Administrative privileges to manage Intune Device Categories.
- PowerShell 5.0 or higher installed on your system.
- The Microsoft Graph PowerShell SDK installed.

## Getting Started

1. **Retrieve Intune Device Category ID:**
   - Visit the Microsoft Graph Explorer at `https://developer.microsoft.com/en-us/graph/graph-explorer`.
   - Perform a GET request to `https://graph.microsoft.com/v1.0/deviceManagement/deviceCategories` to retrieve your Intune Device Category ID.

2. **Prepare the CSV File:**
   - Create a CSV file listing the Intune Device IDs (not Entra IDs).
   - Ensure the CSV file is structured with the appropriate headers and values.

3. **Configure the Script:**
   - Download the `Update-IntuneDeviceCategory.ps1` script from the repository.
   - Open the script in a text editor and specify the path to your CSV file within the script.
   - Update the script with the applicable Device Category ID retrieved from the Microsoft Graph Explorer.

## Usage

To run the script, open PowerShell and navigate to the directory containing the `Update-IntuneDeviceCategory.ps1` file. Execute the script using the following command:

```
.\Update-IntuneDeviceCategory.ps1
```

## License

This script is provided under the MIT License. See the LICENSE file in the repository for full details.

## Author

This script was created by @aappuupatell.

## Support

For support with this script, please raise an issue within the GitHub repository.

## Contributing

Contributions to this script are welcome. Please fork the repository, make your changes, and submit a pull request.

---

Please ensure that you follow the usage steps carefully to avoid any issues with the script execution. For any additional help or clarification, refer to the Microsoft Graph documentation or the PowerShell SDK guidance.
