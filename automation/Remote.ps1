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
    
    New-VM -Name $VMName -Generation 1 -MemoryStartupBytes 6000M B -Path ${env:homepath}\.minikube\machines\ -NewVHDPath ${env:homepath}\.minikube\machines\$VMName\VHD.vhdx -NewVHDSizeBytes 127000MB -SwitchName $SwitchName
    Set-VM -Name $VMName -ProcessorCount 2 -AutomaticCheckpointsEnabled $false  
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true 
    Set-VMDvdDrive -VMName $VMName -Path $ISOFile 
    Start-VM -Name $VMName 
}

# $VMName = 'minikube-m03';
# $UserName = 'Administrator';
# $Password = 'M@kindu.2021';
function Set-Credential {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName,

        [String] 
        [ValidateNotNullOrEmpty()]
        $UserName,

        [String]
        [ValidateNotNullOrEmpty()]
        $Pass
    )

    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force;
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword ;

    return $Credential
    
}

function Rename-Node {
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $NewName = "minikube-m03"
    )
    Set-SConfig -AutoLaunch $false
    Rename-Computer -NewName $NewName 
}

function Install-ContainerFeatures {
    Install-WindowsFeature -Name containers     
}

function Restart-Node {
    Restart-Computer -Force
    
}





function Enable-FireWall-Ports {
    New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
    
}


function Start-RemoteSession {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName,

        [PSCredential]
        [ValidateNotNullOrEmpty()]
        $Credential
    )
    
    Enter-PSSession -VMName $VMName -Credential $Credential;
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