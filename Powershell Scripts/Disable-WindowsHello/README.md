# Disable Windows Hello for Business

This PowerShell script disables Windows Hello for Business for all users on a local machine by modifying the registry. The script is designed to be deployed and executed through Microsoft Intune.

## Description

Windows Hello for Business is feature that provides an alternative method for user authentication using biometric data or PIN. However, in certain scenarios, you may want to disable this feature for all users on a machine. This script achieves that by modifying the `PassportForWork\Enabled` registry key under the `HKLM` hive.

## Prerequisites

- Windows operating system (Windows 10 or later)
- Microsoft Intune subscription and access to the Intune portal
- PowerShell execution policy set to allow script execution

## Usage

1. Download the `Disable-HelloForBusiness.ps1` script from this repository.

2. Sign in to the Microsoft Intune portal (<https://endpoint.microsoft.com/>).

3. Navigate to "Devices" > "Scripts" and click on "Add".

4. Provide a name and description for the script.

5. Upload the `Disable-HelloForBusiness.ps1` script file.

6. Configure the script settings:
   - Run this script using the logged-on credentials: No
   - Enforce script signature check: No
   - Run script in 64-bit PowerShell host: Yes

7. Assign the script to the desired device group(s) or user group(s).

8. The script will be executed on the targeted devices during the next Intune policy sync. It will modify the registry and disable Windows Hello for Business for all users on the machine.

9. Monitor the script execution status and results in the Intune portal under "Devices" > "Scripts" > "Script execution report".

## Note

- This script modifies the registry, which can have significant impact on the system. Make sure to review and understand the script before deploying it through Intune.
- It is recommended to test the script on a small subset of devices before deploying it to a wider audience.
- The script requires administrator privileges to modify the registry, which is handled automatically by Intune when executing the script.

## Author

- Name: @aappuupatell
- Created: 04/16/2024

## License

This script is released under the [MIT License](LICENSE).

## Contributing

If you find any issues or have suggestions for improvements, please open an issue or submit a pull request in this repository.

## Disclaimer

This script is provided as-is without any warranty. Use it at your own risk. The author is not responsible for any damage or loss caused by the usage of this script.

---

Make sure to replace the Intune portal URL (<https://endpoint.microsoft.com/>) with the appropriate URL for your organization if it differs. Also, ensure that you have the necessary permissions and licenses to deploy and execute PowerShell scripts through Microsoft Intune.
