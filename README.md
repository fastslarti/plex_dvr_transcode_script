# Plex DVR Transcode Script
#### PowerShell Script - Transcode Plex DVR Recordings via  [HandBrake CLI](https://handbrake.fr/)

Plex DVR records streams from my HDHomeRun Connect Duo as `MPEG2` encoded `.ts` files. They're unnecessarily HUGE. This script uses [HandBrake CLI](https://handbrake.fr/) to automatically transcode these files and (optionally) delete the originals to save space & bandwidth. It's intended to be run as a scheduled task.

## Usage
Iterates over all `.ts` files in the directory specified by the videoRoot param (or it's default) & all sub-directories and uses [HandBrake CLI](https://handbrake.fr/) to transcode them using the specified preset.

Will create a temporary `transcode_dvr_recordings.lock` file in the directory specified in **--videoRoot** to prevent multiple instances of this script from running in the same directory.

Logs activity in the directory specified in **--videoRoot** in `transcode_dvr_recordings_log.txt`.

###### Global Variables
- **$handbrakePath** - String. Set this to the path to your HandbrakeCLI.exe
- **$presetsPath** - String. Set this to the path to your Handbrake `presets.json` file.

###### Parameters
- **--delete_source** - Switch. When set source `.ts` files will be deleted after transcoding.
- **--use_preset** - String. The Handbrake preset to use ex. `--use_preset:"HQ 1080p30 Surround"`. Would suggest setting a valid default.
- **--videoRoot** - String. The directory containing video files to transcode.
