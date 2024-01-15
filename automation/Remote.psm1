function Get-HyperV {
    $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
    if($hyperv.State -eq "Enabled") {
        Write-Host "Hyper-V is enabled."
    } else {
        Write-Host "Hyper-V is disabled."
    }
    
}

function Set-VmSwitch {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $SwitchName = 'External VM Switch'
    )
    $Switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if ($Switch -eq $null) {
        New-VMSwitch -Name $SwitchName -AllowManagementOS $True -NetAdapterName (Get-NetAdapter | Where-Object {$_.Status -eq 'Up' -and $_.Name -notlike '*vEthernet*'}).Name
    }
    # assign the switch created to a variable and return it from the function
    $Switch = Get-VMSwitch -Name $SwitchName
    return $Switch
}

# pass switch as parameter
function Start-VirtualMachine {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName,

        [String]
        [ValidateNotNullOrEmpty()]
        $SwitchName,

        [String]
        [ValidateNotNullOrEmpty()]
        $ISOFile
    )

    # set the vm switch first
    $Switch = Set-VmSwitch -SwitchName $SwitchName

    $VM = @{
        Name = $VMName
        MemoryStartupBytes = 1GB
        NewVHDPath = "${env:homepath}\.minikube\machines\$VMName\VHD.vhdx"
        NewVHDSizeBytes = 10GB
        BootDevice = "VHD"
        Path = "${env:homepath}\.minikube\machines\"
        SwitchName = $Switch.Name
    }

    New-VM @VM
    
    Set-VM -Name $VMName -ProcessorCount 2 -AutomaticCheckpointsEnabled $false  
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true 
    Set-VMDvdDrive -VMName $VMName -Path $ISOFile 
    Start-VM -Name $VMName 
}

function Set-NodeForMinikube {
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $NewName = "minikube-m03"
    )

    Set-SConfig -AutoLaunch $false
    Restart-Computer -Force
    Install-WindowsFeature -Name containers 
    Restart-Computer -Force
    
}


function Remove-VirtualMachine {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName
    )

    Stop-VM -Name $VMName -TurnOff
    Remove-VM -Name $VMName -Force
    Remove-Item -Path ${env:homepath}\.minikube\machines\$VMName -Force -Recurse
    
}