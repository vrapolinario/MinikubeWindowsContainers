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
    Generation = 1;
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
Set-VMDvdDrive -VMName $VMName -Path $ISOFilePath
Add-VMDvdDrive -VMName $VMName -Path "$PSScriptRoot\auto-install.iso" -ControllerNumber 1 -ControllerLocation 1
Start-VM -Name $VMName | Out-Null



$timeout = 600 
$retryInterval = 15 
$elapsedTime = 0

do {
    Start-Sleep -Seconds $retryInterval
    $heartbeat = Get-VMIntegrationService -VMName $VMName -Name "Heartbeat"
    $elapsedTime += $retryInterval

    if ($elapsedTime -ge $timeout) {
        Write-Output "Timeout reached. Exiting the script."
        exit
    }
} while ($heartbeat.PrimaryStatusDescription -ne "OK")


$SecurePassword = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword

$VMStatus = Get-VM -Name $VMName | Select-Object -ExpandProperty State

if ($VMStatus -eq 'Running') {
    
    Write-Output "The VM $VMName is running"

    $retryInterval = 45 
    $timeout = 120 
    $elapsedTime = 0
    
    do {
        
        try {
            $os = Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock { Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem" } -ErrorAction Stop
            
            if ($os) {
                Write-Output "Windows is installed on $VMName"
                . .\Run.ps1
                # . "$PSScriptRoot\Run.ps1" === this also works
                RUN -VMName $VMName -UserName $UserName -Pass $Pass -Credential $Credential
                break
            } else {
                Write-Output "Windows is not installed on $VMName"
            }
        } catch {
            Write-Output "An error occurred while checking if Windows is installed on ${VMName}: $_"
        }
        Start-Sleep -Seconds $retryInterval
        $elapsedTime += $retryInterval
    } while ($elapsedTime -lt $timeout)

} else {
    Write-Output "The VM $VMName is not running"
}
