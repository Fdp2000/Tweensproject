$diff = git show 1a05577 online-web-browser-test/scenes/LevelScenes/PrototypeLevel.tscn
$minusNodes = @{}
$plusNodes = @{}
foreach ($line in $diff) {
    if ($line -match '^-\[node name="([^"]+)" type="MeshInstance3D" parent="([^"]+)" unique_id=(\d+)\]') {
        $minusNodes[$matches[3]] = $matches[1]
    }
    if ($line -match '^\+\[node name="([^"]+)" type="MeshInstance3D" parent="([^"]+)" unique_id=(\d+)\]') {
        $plusNodes[$matches[3]] = $matches[1]
    }
}
$renames = @{}
foreach ($id in $minusNodes.Keys) {
    if ($plusNodes.ContainsKey($id)) {
        $old = $minusNodes[$id]
        $new = $plusNodes[$id]
        if ($old -ne $new) {
            $renames[$old] = $new
        }
    }
}

$path = "online-web-browser-test/scenes/LevelScenes/PrototypeLevel.tscn"
$lines = Get-Content $path -Encoding UTF8
$outLines = @()
foreach ($line in $lines) {
    if ($line -match '^(.*?)\[node (.*?)\](.*)$') {
        $prefix = $matches[1]
        $nodeContent = $matches[2]
        $suffix = $matches[3]
        
        if ($nodeContent -match 'name="([^"]+)"') {
            $name = $matches[1]
            if ($renames.ContainsKey($name)) {
                $newName = $renames[$name]
                $nodeContent = $nodeContent -replace "name=`"$name`"", "name=`"$newName`""
            }
        }
        
        if ($nodeContent -match 'parent="([^"]+)"') {
            $parent = $matches[1]
            $parts = $parent -split "/"
            $newParts = @()
            foreach ($part in $parts) {
                if ($renames.ContainsKey($part)) {
                    $newParts += $renames[$part]
                } else {
                    $newParts += $part
                }
            }
            $newParent = $newParts -join "/"
            if ($parent -ne $newParent) {
                $nodeContent = $nodeContent.Replace("parent=`"$parent`"", "parent=`"$newParent`"")
            }
        }
        $line = "$prefix[node $nodeContent]$suffix"
    }
    $outLines += $line
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines((Resolve-Path $path).Path, $outLines, $utf8NoBom)
