# Plex DVR Transcode Script
#### PowerShell Script - Transcode Plex DVR Recordings via  [HandBrake CLI](https://handbrake.fr/)

Plex DVR records streams from my HDHomeRun Connect Duo as `MPEG2` encoded `.ts` files. They're unnecessarily HUGE. This script uses [HandBrake CLI](https://handbrake.fr/) to automatically transcode these files and (optionally) delete the originals to save space & bandwidth. It's intended to be run as a scheduled task.

## Usage
Iterates over all `.ts` files in the `-video_root` directory & all sub-directories and uses [HandBrake CLI](https://handbrake.fr/) to transcode them using the specified preset.

Will create a temporary `transcode_dvr_recordings.lock` file in the `-video_root` directory to prevent multiple instances of this script from running on the same content.

Logs activity in the `-video_root` directory in `transcode_dvr_recordings_log.txt`.

###### Parameters
- **-delete_source** - Switch. When set source files will be deleted after transcoding.
- **-file_types** - String. Comma seperated list of file types to transcode. Ex: `-file_types:"*.ts,*.avi,*.mp4"`.
- **-handbrake_path** - String. Path to HandBrakeCLI.exe. Ex: `-handbrake_path:"C:\Program Files\HandBrake\HandBrakeCLI.exe"`.
- **-presets_path** - String. Path to HandBrake presets .json file. Ex: `-presets_path:"C:\Users\[USERNAME]\AppData\Roaming\HandBrake\presets.json"`
- **-use_preset** - String. The Handbrake preset to use. Ex. `-use_preset:"HQ 1080p30 Surround"`
- **-video_root** - String. Root directory containing video files to transcode. Ex: `-video_root:"C:\Users\[USERNAME]\Videos"`.