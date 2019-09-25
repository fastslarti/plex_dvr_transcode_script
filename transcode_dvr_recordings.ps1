param (
    [switch] $delete_source,
    [string] $file_types = "*.ts",
    [Parameter(Mandatory = $true)][string] $handbrake_path,
    [Parameter(Mandatory = $true)][string] $presets_path,
    [Parameter(Mandatory = $true)][string] $use_preset,
    [Parameter(Mandatory = $true)][string] $video_root
)

$fileNameNoEx = "$($MyInvocation.MyCommand)".Remove("$($MyInvocation.MyCommand)".LastIndexOf('.'))
$lockFile = "$video_root\$($fileNameNoEx).lock"
$logFile = "$video_root\$($fileNameNoEx)_log.txt"
$moveToPath = "$video_root\transcoded_originals"

function not-exist { -not (Test-Path $args) }
Set-Alias !exist not-exist -Option "Constant, AllScope"
Set-Alias exist Test-Path -Option "Constant, AllScope"

Function isLocked() {
    if ( exist $lockFile ) {
        if ( ((Get-Date - $lockFile.LastWriteTime).TotalHours) -gt 12 ) {
            Remove-Item -LiteralPath $lockFile -Force -ErrorAction Stop
        }
    }
    return exist $lockFile
}

Function toggleLock() {
    if ( isLocked ) {
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction Stop
    } else {
        New-Item $lockFile
    }
}

Function logger ($logStr) {
    $timeStamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Add-Content $logFile -Value "$timeStamp - $logStr"
}

Function transcodeFile ($source, $destination, $preset) {
    & $handbrake_path -i $source -o $destination  --preset-import-file $presets_path -Z $preset
}

Function getPreset() {
    $presetsObj = Get-Content -Raw -Path $presets_path | ConvertFrom-Json
    foreach ( $line in $presetsObj | Get-Member ) {
        foreach ( $preset in $presetsObj.$($line.Name).ChildrenArray ) {
            if ( $preset.PresetName -eq $use_preset ) {
                return $preset
            }
        }
    }
}

if ( !$delete_source ) {
    if ( !exist $moveToPath ) {
        New-Item -ItemType Directory -Force -Path $moveToPath
    }
}

$thisPreset = getPreset
if ( !($thisPreset) ) {
    logger "SCRIPT START - SCRIPT END - PRESET $use_preset NOT DEFINED IN $presets_path"
} else {
    if ( isLocked ) {
        logger "SCRIPT START - SCRIPT END - LOCK FILE EXISTS"
    } else {
        toggleLock
        $filesToTranscode = Get-ChildItem -Path $video_root -Include $file_types.Split(",") -Recurse | ? {
            $_.FullName -inotmatch ("\\.grab\\") -and $_.FullName -inotmatch ("\\transcoded_originals\\")
        }
        if ( !($filesToTranscode -is [array]) ) {
            $filesToTranscode = @($filesToTranscode)
        }
        if ( $filesToTranscode.length -lt 1 ) {
            logger "SCRIPT START - SCRIPT END - NO FILES FOUND"
        } else {
            logger "SCRIPT START - TRANSCODER PRESET: $use_preset - $($filesToTranscode.length) FILES QUEUED"
            $fileCntr = 0
            $totalMbSaved = 0
            foreach ( $file in $filesToTranscode ) {
                $oldFileName = "$($file.DirectoryName)\$($file.Name)"
                $newFileName = "$($oldFileName.Remove($oldFileName.LastIndexOf('.'))).$($thisPreset.FileFormat)"
                $logOldFileName = $oldFileName.split("\\")[-1]
                $logNewFileName = $newFileName.split("\\")[-1]
                if ( !exist $newFileName ) {
                    $oldFileSize = [math]::Round($file.Length / 1MB)
                    logger "TRANSCODE START - SOURCE FILE: $logOldFileName - $oldFileSize MB"
                    transcodeFile $oldFileName $newFileName $use_preset
                    $newFileSize = [math]::Round((Get-Item $newFileName).length / 1MB)
                    if ( $delete_source ) {
                        Remove-Item -LiteralPath $oldFileName -Force -ErrorAction Stop
                        $totalMbSaved += ($oldFileSize - $newFileSize)
                    } elseif ( !exist "$moveToPath\$($logOldFileName)" ) {
                        Move-Item -path $oldFileName -destination "$moveToPath\$($logOldFileName)"
                    }
                    logger "TRANSCODE END - DESTINATION FILE: $logNewFileName - $newFileSize MB"
                    $fileCntr++
                } else {
                    logger "FILE SKIPPED - $logOldFileName - $logNewFileName ALREADY EXISTS"
                }
            }
            $finalLogStr = "SCRIPT END - FILES TRANSCODED: $fileCntr"
            if ( $fileCntr -lt $filesToTranscode.length ) {
                $finalLogStr += " - FILES SKIPPED: $($filesToTranscode.length - $fileCntr)"
            }
            if ( $delete_source ) {
                $finalLogStr += " - SOURCE FILES DELETED: $totalMbSaved MB Saved"
            }
            logger $finalLogStr
        }
        toggleLock
    }
}
