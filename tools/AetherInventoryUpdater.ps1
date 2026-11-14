Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$repoZip = 'https://github.com/mialtamo/AetherInventory/archive/refs/heads/main.zip'
$donationUrl = 'https://venmo.com/Mike-A-34'
$settingsDir = Join-Path $env:LOCALAPPDATA 'AetherInventoryUpdater'
$settingsFile = Join-Path $settingsDir 'settings.json'
$settings = @{}
if (Test-Path -LiteralPath $settingsFile) {
    try { $settings = Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json -AsHashtable } catch { $settings = @{} }
}
$detectedAddOnsPath = [string]$settings.AddOnsPath
if (-not $detectedAddOnsPath -or -not (Test-Path -LiteralPath $detectedAddOnsPath -PathType Container)) {
    $detectedAddOnsPath = ''
    try {
        $wowProcess = Get-Process -Name 'Wow' -ErrorAction Stop | Select-Object -First 1
        if ($wowProcess.Path) {
            $candidate = Join-Path (Split-Path -Parent $wowProcess.Path) 'Interface\AddOns'
            if (Test-Path -LiteralPath $candidate -PathType Container) { $detectedAddOnsPath = $candidate }
        }
    } catch { }
    if (-not $detectedAddOnsPath) {
        $candidates = @(
            (Join-Path ${env:ProgramFiles(x86)} 'World of Warcraft\_forever_\Interface\AddOns'),
            (Join-Path $env:ProgramFiles 'World of Warcraft\_forever_\Interface\AddOns'),
            'C:\Games\World of Warcraft\_forever_\Interface\AddOns'
        )
        $detectedAddOnsPath = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Aether Inventory Updater'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(560, 245)
$form.MinimumSize = New-Object System.Drawing.Size(560, 245)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.BackColor = [System.Drawing.Color]::FromArgb(39, 34, 50)
$form.ForeColor = [System.Drawing.Color]::White

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Aether Inventory'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(18, 12)
$title.Size = New-Object System.Drawing.Size(500, 36)
$form.Controls.Add($title)

$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Text = 'WoW AddOns folder:'
$pathLabel.Location = New-Object System.Drawing.Point(20, 61)
$pathLabel.Size = New-Object System.Drawing.Size(500, 22)
$form.Controls.Add($pathLabel)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(20, 86)
$pathBox.Size = New-Object System.Drawing.Size(405, 28)
$pathBox.Text = $detectedAddOnsPath
$pathBox.BackColor = [System.Drawing.Color]::FromArgb(250, 247, 240)
$form.Controls.Add($pathBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Text = 'Browse…'
$browse.Location = New-Object System.Drawing.Point(435, 84)
$browse.Size = New-Object System.Drawing.Size(95, 31)
$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select World of Warcraft\_classic_\Interface\AddOns (or your version folder’s Interface\AddOns).'
    $dialog.SelectedPath = $pathBox.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $pathBox.Text = $dialog.SelectedPath }
})
$form.Controls.Add($browse)

$install = New-Object System.Windows.Forms.Button
$install.Text = 'Install latest update'
$install.Location = New-Object System.Drawing.Point(20, 127)
$install.Size = New-Object System.Drawing.Size(330, 40)
$install.BackColor = [System.Drawing.Color]::FromArgb(114, 78, 151)
$install.ForeColor = [System.Drawing.Color]::White
$install.FlatStyle = 'Flat'
$form.Controls.Add($install)

$donate = New-Object System.Windows.Forms.Button
$donate.Text = 'Donate via Venmo'
$donate.Location = New-Object System.Drawing.Point(370, 127)
$donate.Size = New-Object System.Drawing.Size(160, 40)
$donate.BackColor = [System.Drawing.Color]::FromArgb(58, 145, 171)
$donate.ForeColor = [System.Drawing.Color]::White
$donate.FlatStyle = 'Flat'
$donate.Add_Click({ Start-Process $donationUrl })
$form.Controls.Add($donate)

$status = New-Object System.Windows.Forms.Label
$status.Text = if ($pathBox.Text) { 'WoW AddOns folder found. Click Install latest update.' } else { 'Choose your WoW AddOns folder, then click Install.' }
$status.Location = New-Object System.Drawing.Point(20, 180)
$status.Size = New-Object System.Drawing.Size(510, 28)
$form.Controls.Add($status)

$install.Add_Click({
    $addOnsPath = $pathBox.Text.Trim()
    if (-not $addOnsPath -or -not (Test-Path -LiteralPath $addOnsPath -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show('Select an existing WoW Interface\AddOns folder first.', 'Folder needed', 'OK', 'Information') | Out-Null
        return
    }
    $install.Enabled = $false
    $browse.Enabled = $false
    $donate.Enabled = $false
    $status.Text = 'Downloading latest files…'
    [System.Windows.Forms.Application]::DoEvents()
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('AetherInventory-' + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot 'source.zip'
    $extractPath = Join-Path $tempRoot 'extracted'
    $destination = Join-Path $addOnsPath 'AetherInventory'
    $backup = Join-Path $tempRoot 'previous'
    try {
        New-Item -ItemType Directory -Path $tempRoot, $extractPath | Out-Null
        Invoke-WebRequest -Uri $repoZip -OutFile $zipPath -UseBasicParsing -Headers @{ 'User-Agent' = 'AetherInventoryUpdater' }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
        $releaseZip = Get-ChildItem -LiteralPath $extractPath -Filter 'latest.zip' -File -Recurse | Select-Object -First 1
        $sourceRoot = $extractPath
        if ($releaseZip) {
            $releasePath = Join-Path $tempRoot 'release'
            New-Item -ItemType Directory -Path $releasePath | Out-Null
            Expand-Archive -LiteralPath $releaseZip.FullName -DestinationPath $releasePath -Force
            $sourceRoot = $releasePath
        }
        $addonSource = Get-ChildItem -LiteralPath $sourceRoot -Directory -Recurse | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'AetherInventory.toc') } | Select-Object -First 1
        if (-not $addonSource) { throw 'The downloaded files did not contain AetherInventory.toc.' }
        $stage = Join-Path $tempRoot 'AetherInventory-new'
        Copy-Item -LiteralPath $addonSource.FullName -Destination $stage -Recurse
        if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination $backup }
        try { Move-Item -LiteralPath $stage -Destination $destination }
        catch {
            if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $destination }
            throw
        }
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        @{ AddOnsPath = $addOnsPath } | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
        $versionLine = Select-String -LiteralPath (Join-Path $destination 'AetherInventory.toc') -Pattern '^## Version:' | Select-Object -First 1
        $version = if ($versionLine) { $versionLine.Line -replace '^## Version:\s*', '' } else { 'latest' }
        $status.Text = "Installed version $version. In WoW, type /reload to load it."
        [System.Windows.Forms.MessageBox]::Show("Aether Inventory $version is installed.`r`n`r`nReturn to WoW and type /reload.", 'Update complete', 'OK', 'Information') | Out-Null
    }
    catch {
        $status.Text = 'Update failed. Your previous copy was kept when possible.'
        [System.Windows.Forms.MessageBox]::Show("Could not install the update:`r`n$($_.Exception.Message)", 'Update failed', 'OK', 'Error') | Out-Null
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
        $install.Enabled = $true
        $browse.Enabled = $true
        $donate.Enabled = $true
    }
})

[void]$form.ShowDialog()

