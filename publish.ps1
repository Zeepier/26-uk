$vault     = "C:\Users\Projects\Documents\Obsidian notes\Reizen\26 UK"
$quartz    = $PSScriptRoot
$content   = "$quartz\content"
$attach    = "C:\Users\Projects\Documents\Obsidian notes\Reizen\attachments"
$vaultRoot = "C:\Users\Projects\Documents\Obsidian notes\Reizen"

Write-Host "Syncing 26 UK notes to site..."

# Clear existing markdown (keep attachments folder)
Get-ChildItem "$content" -Filter "*.md" | Remove-Item -Force
New-Item -ItemType Directory -Force "$content\Reizen & reserveringen" | Out-Null
Get-ChildItem "$content\Reizen & reserveringen" -Filter "*.md" -ErrorAction SilentlyContinue | Remove-Item -Force
New-Item -ItemType Directory -Force "$content\attachments" | Out-Null

# Copy markdown files, prepending password frontmatter
$frontmatter = "---`npassword: likeaG6`n---`n`n"
foreach ($f in (Get-ChildItem "$vault" -Recurse -Filter "*.md")) {
    $rel  = $f.FullName.Substring($vault.Length).TrimStart('\')
    $dest = "$content\$rel"
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    $body = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($dest, $frontmatter + $body, [System.Text.Encoding]::UTF8)
}

# Itinerary becomes the landing page
if (Test-Path "$content\Itinerary.md") {
    Move-Item "$content\Itinerary.md" "$content\index.md" -Force
}

# Copy images and PDFs referenced in the notes
$mdFiles = Get-ChildItem "$content" -Recurse -Filter "*.md"
$referenced = Select-String -Path $mdFiles.FullName -Pattern '!?\[\[([^\]]+)\]\]' |
    ForEach-Object { $_.Matches.Groups[1].Value -replace '\|.*','' }
foreach ($file in ($referenced | Sort-Object -Unique)) {
    $src = if (Test-Path "$attach\$file")       { "$attach\$file" }
           elseif (Test-Path "$vaultRoot\$file") { "$vaultRoot\$file" }
           else { $null }
    if ($src) { Copy-Item $src "$content\attachments\$file" -Force }
}

# Commit and push
Set-Location $quartz
git add content/
$changed = git status --short
if (-not $changed) {
    Write-Host "No changes since last publish."
    exit 0
}
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "Update 26 UK — $timestamp"
git push origin HEAD:main

Write-Host "`nDone! Site will update at https://zeepier.github.io/26-uk in ~2 minutes."
