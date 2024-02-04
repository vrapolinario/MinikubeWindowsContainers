# Define the paths to the ISO and the Autounattend.xml file
$isoPath = "D:\MinikubeWindowsContainers\SERVER_EVAL_x64FRE_en-us.iso"
$answerFilePath = "D:\MinikubeWindowsContainers\automation\autounattend.xml"

# Mount the ISO
$iso = Mount-DiskImage -ImagePath $isoPath -PassThru
$driveLetter = ($iso | Get-Volume).DriveLetter

# Copy the Autounattend.xml file to the root of the ISO
Copy-Item -Path $answerFilePath -Destination "$($driveLetter):\" -Force

# Start the installation
Start-Process -FilePath "$($driveLetter):\setup.exe" -ArgumentList "/unattend:$($driveLetter):\Autounattend.xml"
