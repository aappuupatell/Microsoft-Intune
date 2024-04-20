### Overview:

1. The script begins by configuring essential settings for the script's operation, like TLS for secure connections.
2. It navigates to the "Windows Autopilot" directory and adjusts necessary environment variables.
3. The script then installs essential package providers and scripts, most notably the `Get-WindowsAutopilotInfo` script.
4. It extracts Autopilot information into a CSV format, specifically focusing on `Device Serial Number`, `Windows Product ID`, and `Hardware Hash`.
5. The script then interacts with the GitHub API to fetch the existing CSV, combines the new information with the existing data, and pushes this updated CSV back to the repository.

### Prerequisites:

- Windows PowerShell with administrative privileges.
- The machine from which the script is run should have the `Get-WindowsAutopilotInfo` module or the script will install it.
- A GitHub personal access token with appropriate permissions (especially for pushing to repositories).
- A GitHub repository where the Autopilot CSV data will be stored.

### Usage:

1. **Setup**:
   - Clone this repository to your local machine.
   - Ensure you have PowerShell installed and configured to run scripts (`RemoteSigned` execution policy is set in the script).
   - Update the `$token` variable in the script with your GitHub personal access token.
   - Adjust `$owner`, `$repo`, and `$branch` if you are pointing to a different repository or branch.

2. **Run the script**:
   - Open a PowerShell session with administrative privileges.
   - Navigate to the directory containing the script.
   - Execute the script.

3. Once executed, the script will do the following:
   - Fetch Windows Autopilot information from the machine.
   - Consolidate this data into `AutopilotHWID.csv`.
   - Push this updated CSV to the specified GitHub repository.

### Notes:

- Ensure that you never commit the script with your personal GitHub token to any public repository for security reasons.
- The script assumes that the Autopilot CSV in the repository is named `AutopilotHWID.csv`.
- This script performs several operations with the GitHub API, including fetching content, creating blobs, creating trees, creating commits, and updating references. Familiarize yourself with these operations if you wish to make any modifications.

### Contributions:

Contributions to improve this script or its functionalities are always welcome. Please follow typical GitHub practices of forking the repo, making your changes, and submitting a pull request.

### License:

This script is provided under the MIT License. See `LICENSE` for more details. 

### Disclaimer:

Ensure you test the script in a controlled environment before running it in production. The authors/maintainers are not responsible for any unintended side effects or damages resulting from using this script.
