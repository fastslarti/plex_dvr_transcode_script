# See README.md for parameter definitions
param (
    [switch] $delete_source,
    [string] $file_types = "*.ts",
    [Parameter(Mandatory = $true)][string] $handbrake_path,
    [Parameter(Mandatory = $true)][string] $presets_path,
    [Parameter(Mandatory = $true)][string] $use_preset,
    [Parameter(Mandatory = $true)][string] $video_root
)

# Create lock & log file paths in video_root directory
$fileNameNoEx = "$($MyInvocation.MyCommand)".Remove("$($MyInvocation.MyCommand)".LastIndexOf('.'))
$lockFile = "$video_root\$($fileNameNoEx).lock"
$logFile = "$video_root\$($fileNameNoEx)_log.txt"
$moveToPath = "$video_root\transcoded_originals"

# Function & aliases for checking if file/directory exists
function not-exist { -not (Test-Path $args) }
Set-Alias !exist not-exist -Option "Constant, AllScope"
Set-Alias exist Test-Path -Option "Constant, AllScope"

# Checks for existence of lock file, returns boolean
Function isLocked() {
    return Test-Path -LiteralPath $lockFile
}

# Creates lock file if it dosen't exist, deletes it if it does
Function toggleLock() {
    if ( isLocked ) {
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction Stop
    } else {
        New-Item $lockFile
    }
}

# Writes $logStr argument to $logFile
Function logger ($logStr) {
    $timeStamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Add-Content $logFile -Value "$timeStamp - $logStr"
}

# Calls HandBrake w/source file path, destination file path, preset file path, and selected preset argument
Function transcodeFile ($source, $destination, $preset) {
    & $handbrake_path -i $source -o $destination  --preset-import-file $presets_path -Z $preset
}

# Gets transcoder preset from $presets_path json
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

# If $delete_source=false ensure original storage directory exists
if ( !$delete_source ) {
    if ( !exist $moveToPath ) {
        New-Item -ItemType Directory -Force -Path $moveToPath
    }
}


$thisPreset = getPreset
# If specifed preset exists in specified preset file json
if ( !($thisPreset) ) {
    logger "SCRIPT START - SCRIPT END - PRESET $use_preset NOT DEFINED IN $presets_path"
} else {
    # Lock file ensures one instance only
    if ( isLocked ) {
        logger "SCRIPT START - SCRIPT END - LOCK FILE EXISTS"
    } else {
        # Create lock file
        toggleLock
        # Recursively gathers files of the types specified in -file_types in the -video_root directory to transcode, excludes files in .grab directories.
        # Get-ChildItem returns a System.IO.FileInfo object if only one file is found, or an array of System.IO.FileInfo objects if multiple files are found
        $filesToTranscode = Get-ChildItem -Path $video_root -Include $file_types.Split(",") -Recurse | ? {
            $_.FullName -inotmatch ("\\.grab\\") -and $_.FullName -inotmatch ("\\transcoded_originals\\")
        }
        if ( !($filesToTranscode -is [array]) ) {
            $filesToTranscode = @($filesToTranscode)
        }
        if ( $filesToTranscode.length -lt 1 ) {
            logger "SCRIPT START - SCRIPT END - NO FILES FOUND"
        } else {
            # Log Script Start
            logger "SCRIPT START - TRANSCODER PRESET: $use_preset - $($filesToTranscode.length) FILES QUEUED"
            $fileCntr = 0
            $totalMbSaved = 0
            foreach ( $file in $filesToTranscode ) {
                # Create source .ts file path
                $oldFileName = "$($file.DirectoryName)\$($file.Name)"
                # Create destination file path
                $newFileName = "$($oldFileName.Remove($oldFileName.LastIndexOf('.'))).$($thisPreset.FileFormat)"
                # Create logged filenames
                $logOldFileName = $oldFileName.split("\\")[-1]
                $logNewFileName = $newFileName.split("\\")[-1]
                # Verify destination file doesn't already exist
                if ( !exist $newFileName ) {
                    # Calculate size of original file
                    $oldFileSize = [math]::Round($file.Length / 1MB)
                    # Log transcode start
                    logger "TRANSCODE START - SOURCE FILE: $logOldFileName - $oldFileSize MB"
                    # Run handbrake on current file
                    transcodeFile $oldFileName $newFileName $use_preset
                    # Calculate size of destination file
                    $newFileSize = [math]::Round((Get-Item $newFileName).length / 1MB)
                    # Delete source .ts file
                    if ( $delete_source ) {
                        Remove-Item -LiteralPath $oldFileName -Force -ErrorAction Stop
                        $totalMbSaved += ($oldFileSize - $newFileSize)
                    } elseif ( !exist "$moveToPath\$($logOldFileName)" ) {
                        Move-Item -path $oldFileName -destination "$moveToPath\$($logOldFileName)"
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
        }
        # Delete lock file
        toggleLock
    }
}
