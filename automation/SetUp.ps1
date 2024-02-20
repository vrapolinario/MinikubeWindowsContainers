param(
    [Parameter(Mandatory=$true)]
    [string]$SwitchName,

    [Parameter(Mandatory=$true)]
    [string]$ISOFilePath,

    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$UserName,

    [Parameter(Mandatory=$true)]
    [string]$Pass
)

$VM = @{
    Name = $VMName;
    MemoryStartupBytes = 1GB;
    NewVHDPath = "${env:homepath}\.minikube\machines\$VMName\VHD.vhdx";
    NewVHDSizeBytes = 15GB;
    BootDevice = "VHD";
    Path = "${env:homepath}\.minikube\machines\";
    SwitchName = $SwitchName
}

New-VM @VM
Set-VM -Name $VMName -ProcessorCount 2 -AutomaticCheckpointsEnabled $false
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
Set-VMDvdDrive -VMName $VMName -Path $ISOFile
Add-VMDvdDrive -VMName $VMName -Path "$PSScriptRoot\auto-install.iso" -ControllerNumber 1 -ControllerLocation 1
Start-VM -Name $VMName


# Wait for the VM to have a Heartbeat status of OK
$timeout = 300 # 5 minutes
$elapsedTime = 0

do {
    Start-Sleep -Seconds 5 # wait for 5 seconds before checking again
    $heartbeat = Get-VMIntegrationService -VMName $VMName -Name "Heartbeat"
    $elapsedTime += 5

    if ($elapsedTime -ge $timeout) {
        Write-Output "Timeout reached. Exiting the script."
        exit
    }
} while ($heartbeat.PrimaryStatusDescription -ne "OK")

# Check if Windows is installed only if the Heartbeat status is OK
if ($heartbeat.PrimaryStatusDescription -eq "OK") {
    try {
        $SecurePassword = ConvertTo-SecureString -String $Pass -AsPlainText -Force
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword

        $os = Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock { Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem" } -ErrorAction Stop
        if ($os) {
            Write-Output "Windows is installed on $VMName"
            # Call Run.ps1
            . .\Run.ps1
            Invoke-Expression "Run -VMName $VMName -UserName $UserName -Pass $Pass"
        } else {
            Write-Output "Windows is not installed on $VMName"
        }
    } catch {
        Write-Output "An error occurred while checking if Windows is installed on ${VMName}: $_"
    }
}