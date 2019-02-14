param (
    [switch] $delete_source, # If script is run w/--delete_source param, source .ts files will be deleted automatically after transcoding
    [string] $use_preset = "[Default Handbrake Preset To Use]", # Example: "HQ 1080p30 Surround"
    [string] $videoRoot = "[Root Video Dir]" # Root directory containing video files to transcode. Example: "C:\Users\[USERNAME]\Videos"
)

$handbrakePath = "[Path to HandBrakeCLI.exe]" # Example: "C:\Program Files\HandBrake\HandBrakeCLI.exe"
$presetsPath = "[Path to Handbrake Preset File]" # Example: "C:\Users\[USERNAME]\AppData\Roaming\HandBrake\presets.json"
$fileNameNoEx = "$($MyInvocation.MyCommand)".Remove("$($MyInvocation.MyCommand)".LastIndexOf('.'))
$lockFile = "$videoRoot\$($fileNameNoEx).lock"
$logFile = "$videoRoot\$($fileNameNoEx)_log.txt"

# Checks for existence of lock file, returns boolean
Function testLock() {
    return test-path -LiteralPath $lockFile
}

# Creates lock file if it dosen't exist, deletes it if it does
Function toggleLock() {
    if ( testLock $lockFile ) {
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction Stop
    } else {
        new-item $lockFile
    }
}

# Writes $logStr argument to $logFile
Function logger ($logStr) {
    $timeStamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Add-Content $logFile -Value "$timeStamp - $logStr"
}

# Calls HandBrake w/source file path, destination file path, preset file path, and selected preset argument
Function transcodeFile ($source, $destination, $preset) {
    & $handbrakePath -i $source -o $destination  --preset-import-file $presetsPath -Z $preset
}

# Lock file ensures one instance only
If ( !(testLock) ) {
    # Create lock file
    toggleLock
    # Recursively gathers .ts files in the videoRoot directory to transcode, excludes files in .grab directories
    $filesToTranscode = Get-ChildItem -Path $videoPath -Include *.ts -Recurse | ? {
        $_.FullName -inotmatch "\\.grab\\"
    }
    # Log Script Start
    if ( $filesToTranscode.length -gt 0 ) {
        logger "SCRIPT START - TRANSCODER PRESET: $use_preset - $($filesToTranscode.length) FILES QUEUED"
        $fileCntr = 0
        $totalMbSaved = 0
        foreach ( $file in $filesToTranscode ) {
            $oldFileName = "$($file.DirectoryName)\$($file.Name)"
            # Create destination .mp4 file path
            $newFileName = "$($oldFileName.Remove($oldFileName.LastIndexOf('.'))).mp4"
            # Create logged filenames
            $logOldFileName = $oldFileName.split("\\")[-1]
            $logNewFileName = $newFileName.split("\\")[-1]
            # Verify destination file doesn't already exist
            if ( !(test-path -LiteralPath $newFileName) ) {
                $oldFileSize = [math]::Round($file.Length / 1MB)
                # Log transcode start
                logger "TRANSCODE START - SOURCE FILE: $logOldFileName - $oldFileSize MB"
                # Run handbrake on current file
                transcodeFile $oldFileName $newFileName $use_preset
                $newFileSize = [math]::Round((Get-Item $newFileName).length / 1MB)
                # Delete source .ts file
                if ( $delete_source ) {
                    Remove-Item -LiteralPath $oldFileName -Force -ErrorAction Stop
                    $totalMbSaved += ($oldFileSize - $newFileSize)
                }
                # Log transcode end
                logger "TRANSCODE END - DESTINATION FILE: $logNewFileName - $newFileSize MB"
                $fileCntr++
            } else {
                logger "FILE SKIPPED - $logOldFileName - $logNewFileName ALREADY EXISTS"
            }
        }
        # Log Script End
        $finalLogStr = "SCRIPT END - FILES TRANSCODED: $fileCntr"
        if ( $fileCntr -lt $filesToTranscode.length ) {
            $finalLogStr += " - FILES SKIPPED: $($filesToTranscode.length - $fileCntr)"
        }
        # If source files deleted, append space saved to final log string
        if ( $delete_source ) {
            $finalLogStr += " - SOURCE FILES DELETED: $totalMbSaved MB Saved"
        }
        logger $finalLogStr
    } else {
        logger "SCRIPT START - SCRIPT END - NO FILES FOUND"
    }
    # Delete lock file
    toggleLock
} else {
    logger "SCRIPT START - SCRIPT END - LOCK FILE EXISTS"
}
