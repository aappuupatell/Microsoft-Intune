[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-Location -Path "C:\Windows Autopilot" -ErrorAction SilentlyContinue
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Script -Name Get-WindowsAutopilotInfo -Force

 

# Exporting device info to CSV without headers
Get-WindowsAutopilotInfo | ForEach-Object {
    [PSCustomObject]@{
        'Device Serial Number' = $_.'Device Serial Number';
        'Windows Product ID'   = $_.'Windows Product ID';
        'Hardware Hash'        = $_.'Hardware Hash';
    }
} | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Set-Content AutopilotHWID.csv

 

# GitHub Variables
$token = ""
$owner = ""
$repo = ""
$branch = "main"
$headers = @{
    "Authorization" = "token $token"
    "User-Agent" = "Powershell"
}

 

# Fetch the existing CSV content from GitHub
$existingFile = Invoke-RestMethod -Uri "xxxxxxxxxxxxxx/xxxxxxxx/xxxxxx/xxxxxxx/AutopilotHWID.csv" -Headers $headers
$existingContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($existingFile.content))

 

# Append the new data to the existing content
$combinedContent = $existingContent + (Get-Content AutopilotHWID.csv -Raw)

 

# Convert the combined CSV content to Base64
$base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($combinedContent))

 

# Fetch the SHA of the latest commit
$latestCommitSHA = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/git/ref/heads/$branch" -Headers $headers | select -ExpandProperty object | select -ExpandProperty sha

 

# Create a new blob with the combined content
$blob = @{
    content = $base64Content
    encoding = "base64"
}
$newBlobSHA = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/git/blobs" -Method POST -Headers $headers -Body ($blob | ConvertTo-Json) | select -ExpandProperty sha

 

# Create a new tree pointing to the blob
$tree = @{
    base_tree = $latestCommitSHA
    tree = @(
        @{
            path = "AutopilotHWID.csv"
            mode = "100644"
            type = "blob"
            sha = $newBlobSHA
        }
    )
}
$newTreeSHA = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/git/trees" -Method POST -Headers $headers -Body ($tree | ConvertTo-Json) | select -ExpandProperty sha

 

# Create a new commit
$commit = @{
    message = "Update AutopilotHWID.csv via script"
    parents = @($latestCommitSHA)
    tree = $newTreeSHA
}
$newCommitSHA = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/git/commits" -Method POST -Headers $headers -Body ($commit | ConvertTo-Json) | select -ExpandProperty sha

 

# Update the branch to point to the new commit
$ref = @{
    sha = $newCommitSHA
}
Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/git/refs/heads/$branch" -Method PATCH -Headers $headers -Body ($ref | ConvertTo-Json)