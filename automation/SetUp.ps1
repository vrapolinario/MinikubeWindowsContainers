param(
    [string]$SwitchName = "Default Switch",

    [Parameter(Mandatory=$true)]
    [string]$ISOFilePath,

    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$true)]
    [string]$UserName,

    [Parameter(Mandatory=$true)]
    [string]$Pass,

    [string]$KubernetesVersion
)

Import-Module -Name "$PSScriptRoot\k8Tools.psm1" -Force


if ([string]::IsNullOrEmpty($KubernetesVersion)) {
    $KubernetesVersion = Get-k8LatestVersion
    Write-Output "* The latest Kubernetes version is $KubernetesVersion"
    $KubernetesVersion = $KubernetesVersion.TrimStart('v')
}


"* Starting the $VMName Virtual Machine ..." > logs
Write-Output "* Starting the $VMName Virtual Machine ..."

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

Write-Output "* Please wait as we set up the $VMName Virtual Machine ..."
New-VM @VM | Out-Null
Set-VM -Name $VMName -ProcessorCount 2 -AutomaticCheckpointsEnabled $false
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
Set-VMDvdDrive -VMName $VMName -Path $ISOFilePath
# Add-VMDvdDrive -VMName $VMName -Path "$PSScriptRoot\auto-install.iso" -ControllerNumber 1 -ControllerLocation 1
Start-VM -Name $VMName | Out-Null



$timeout = 600 
$retryInterval = 15 
$elapsedTime = 0

do {
    Start-Sleep -Seconds $retryInterval
    "Waiting for the VM to start ..." >> logs
    $heartbeat = Get-VMIntegrationService -VMName $VMName -Name "Heartbeat"
    $elapsedTime += $retryInterval

    if ($elapsedTime -ge $timeout) {
        Write-Output "* Timeout reached. Unable to start the VM ..."
        Write-Output "* Exiting the script ..."
        "Timeout reached. Exiting the script ..." >> logs
        "Exiting the script ..." >> logs
        exit
    }
} while ($heartbeat.PrimaryStatusDescription -ne "OK")

Write-Output "* The $VMName Virtual Machine is started ..."


$SecurePassword = ConvertTo-SecureString -String $Pass -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword

$VMStatus = Get-VM -Name $VMName | Select-Object -ExpandProperty State

if ($VMStatus -eq 'Running') {
    
    "The $VMName Virtual Machine is running" >> logs

    $retryInterval = 45 
    $timeout = 120 
    $elapsedTime = 0
    
    do {
        
        try {
            $os = Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock { Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem" } -ErrorAction Stop
            
            if ($os) {
                Write-Output "* Windows is successfully installed on $VMName"
                "Windows is successfully installed on $VMName" >> logs
                . .\Run.ps1
                # . "$PSScriptRoot\Run.ps1" === this also works
                RUN -VMName $VMName -UserName $UserName -Pass $Pass -Credential $Credential -KubernetesVersion $KubernetesVersion
                break
            } else {
                Write-Output "* Windows is not installed on $VMName"
            }
        } catch {
            Write-Output "* An error occurred while checking if Windows is installed on ${VMName}: $_"
        }
        Start-Sleep -Seconds $retryInterval
        $elapsedTime += $retryInterval
    } while ($elapsedTime -lt $timeout)

} else {
    Write-Output "The VM $VMName is not running"
}
