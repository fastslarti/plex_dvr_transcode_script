param (
    [switch] $delete_source, # If script is run w/--delete_source param, source .ts files will be deleted automatically after transcoding
    [string] $use_preset = "[Default Handbrake Preset To Use]" # Example: "HQ 1080p30 Surround"
)
$lockFile = "$PSScriptRoot\$($MyInvocation.MyCommand)" -replace ".ps1", ".lock"
$logFile = "$PSScriptRoot\$($MyInvocation.MyCommand)" -replace ".ps1", "_log.txt"
$handbrakePath = "[Path to HandBrakeCLI.exe]" # Example: "C:\Program Files\HandBrake\HandBrakeCLI.exe"
$presetsPath = "[Path to Handbrake Preset File]" # Example: "C:\Users\[USERNAME]\AppData\Roaming\HandBrake\presets.json"

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

# Log Script Start
logger "SCRIPT START - TRANSCODER PRESET: $use_preset"

# Lock file ensures one instance only
If ( !(testLock) ) {
    # Create lock file
    toggleLock
    $fileCntr = 0
    $totalMbSaved = 0
    # Iterates over all .ts files in all sub-directories
    Get-ChildItem *.ts -recurse | foreach {
        # Skip .grab directories
        if ( !($_.FullName -like '*grab*') ) {
            # Create destination .mp4 file path
            $newFileName = "$($_.FullName.SubString(0, $_.FullName.length - 3)).mp4"
            # Create logged filenames
            $logOldFileName = $_.FullName.split("\\")[-1]
            $logNewFileName = $newFileName.split("\\")[-1]
            # Verify destination file doesn't already exist
            if ( !(test-path -LiteralPath $newFileName) ) {
                $oldFileSize = [math]::Round($_.Length / 1MB)
                # Log transcode start
                logger "TRANSCODE START - SOURCE FILE: $logOldFileName - $oldFileSize MB"
                # Run handbrake on current file
                transcodeFile $_.FullName $newFileName $use_preset
                $newFileSize = [math]::Round((Get-Item $newFileName).length / 1MB)
                # Delete source .ts file
                if ( $delete_source ) {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                    $totalMbSaved += ($oldFileSize - $newFileSize)
                }
                # Log transcode end
                logger "TRANSCODE END - DESTINATION FILE: $logNewFileName - $newFileSize MB"
                $fileCntr++
            } else {
                logger "FILE SKIPPED - $logOldFileName - $logNewFileName ALREADY EXISTS"
            }
        }
    }
    # Log Script End
    if ( $fileCntr -gt 0 ) {
        $finalLogStr = "SCRIPT END - $fileCntr FILES TRANSCODED"
        # If source files deleted, append space saved to final log string
        if ( $delete_source ) {
            $finalLogStr += " - SOURCE FILES DELETED: $totalMbSaved MB Saved"
        }
    } else {
        $finalLogStr = "SCRIPT END - NO FILES ELIGIBLE FOR TRANSCODE"
    }
    Logger $finalLogStr
    # Delete lock file
    toggleLock
} else {
    logger "SCRIPT END - LOCK FILE EXISTS"
}
