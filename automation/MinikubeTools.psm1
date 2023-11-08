function Start-Minikube {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $SwitchName = "External VM Switch"
    )
    
    minikube start --driver=hyperv --hyperv-virtual-switch=$SwitchName --nodes=2 --cni=flannel --container-runtime=containerd
}

function Get-LinuxMasterNodeIP {
    $IP = minikube ip
    return $IP
    
}

function Set-Flannel {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $NodeName 
    )

    if ($NodeName) {
        minikube ssh "sudo sysctl net.bridge.bridge-nf-call-iptables=1 && exit"
    } else {
        minikube ssh -n $NodeName "sudo sysctl net.bridge.bridge-nf-call-iptables=1 && exit"
    }

}

function Get-JoinCommand {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $Version = "v1.27.3"
    )

    $JoinCommand = (minikube ssh "cd /var/lib/minikube/binaries/v1.27.3/ && sudo ./kubeadm token create --print-join-command") 

    # Replace 'kubeadm' with '.\kubeadm'
    $outputString = $JoinCommand -replace 'kubeadm', '.\kubeadm'

    # Append '--cri-socket "npipe:////./pipe/containerd-containerd"'
    $outputString += ' --cri-socket "npipe:////./pipe/containerd-containerd"'

    # Print the modified string
    Write-Host $outputString

    return $outputString

}

function Set-MinikubeFolderError {
    mkdir c:\var\lib\minikube\certs
    Copy-Item C:\etc\kubernetes\pki\ca.crt -Destination C:\var\lib\Minikube\Certs
    Remove-Item C:\etc\kubernetes\pki\ca.crt
}

function Add-Host {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $IP,
        [string]
        [ValidateNotNullOrEmpty()]
        $Path = "C:\Windows\System32\drivers\etc\hosts"
    )

    Add-Content -Path $Path -Value "`n`t`t$IP`tcontrol-plane.minikube.internal" -Force
    
}


Export-ModuleMember -Function Start-Minikube
Export-ModuleMember -Function Get-LinuxMasterNodeIP
Export-ModuleMember -Function Set-Flannel
Export-ModuleMember -Function Get-JoinCommand
Export-ModuleMember -Function Invoke-RunCommand
Export-ModuleMember -Function Set-MinikubeFolderError
Export-ModuleMember -Function Add-Host