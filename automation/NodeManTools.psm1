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

    $VM = @{
        Name = $VMName
        MemoryStartupBytes = 1GB
        NewVHDPath = "${env:homepath}\.minikube\machines\$VMName\VHD.vhdx"
        NewVHDSizeBytes = 10GB
        BootDevice = "VHD"
        Path = "${env:homepath}\.minikube\machines\"
        SwitchName = (Get-VMSwitch).Name
    }

    New-VM @VM
    
    # New-VM -Name $VMName -Generation 1 -MemoryStartupBytes 6000MB -Path ${env:homepath}\.minikube\machines\ -NewVHDPath ${env:homepath}\.minikube\machines\$VMName\VHD.vhdx -NewVHDSizeBytes 127000MB -SwitchName $SwitchName
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