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

Function isLocked() {
    return Test-Path -LiteralPath $lockFile
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

$thisPreset = getPreset
if ( $thisPreset ) {
    if ( !(isLocked) ) {
        toggleLock
        $filesToTranscode = Get-ChildItem -Path $video_root -Include $file_types.Split(",") -Recurse | ? {
            $_.FullName -inotmatch "\\.grab\\"
        }
        if ( !($filesToTranscode -is [array]) ) {
            $filesToTranscode = @($filesToTranscode)
        }
        if ( $filesToTranscode.length -gt 0 ) {
            logger "SCRIPT START - TRANSCODER PRESET: $use_preset - $($filesToTranscode.length) FILES QUEUED"
            $fileCntr = 0
            $totalMbSaved = 0
            foreach ( $file in $filesToTranscode ) {
                $oldFileName = "$($file.DirectoryName)\$($file.Name)"
                $newFileName = "$($oldFileName.Remove($oldFileName.LastIndexOf('.'))).$($thisPreset.FileFormat)"
                $logOldFileName = $oldFileName.split("\\")[-1]
                $logNewFileName = $newFileName.split("\\")[-1]
                if ( !(test-path -LiteralPath $newFileName) ) {
                    $oldFileSize = [math]::Round($file.Length / 1MB)
                    logger "TRANSCODE START - SOURCE FILE: $logOldFileName - $oldFileSize MB"
                    transcodeFile $oldFileName $newFileName $use_preset
                    $newFileSize = [math]::Round((Get-Item $newFileName).length / 1MB)
                    if ( $delete_source ) {
                        Remove-Item -LiteralPath $oldFileName -Force -ErrorAction Stop
                        $totalMbSaved += ($oldFileSize - $newFileSize)
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
        } else {
            logger "SCRIPT START - SCRIPT END - NO FILES FOUND"
        }
        toggleLock
    } else {
        logger "SCRIPT START - SCRIPT END - LOCK FILE EXISTS"
    }
} else {
    logger "SCRIPT START - SCRIPT END - PRESET $use_preset NOT DEFINED IN $presets_path"
}
