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
    $JoinCommand = (minikube ssh "cd /var/lib/minikube/binaries/v1.27.3/ && sudo ./kubeadm token create --print-join-command") >> logs
    $outputString = $JoinCommand -replace 'kubeadm', '.\kubeadm'
    $outputString += ' --cri-socket "npipe:////./pipe/containerd-containerd"'
    $outputString += ' --v=5'
    # Write-Host $outputString
    # write this to a log file
    return $outputString

}

function Set-MinikubeFolderError {
    if (!(Test-Path -Path c:\var\lib\minikube\certs)) {
        mkdir c:\var\lib\minikube\certs | Out-Null
    }

    if (Test-Path -Path C:\etc\kubernetes\pki\ca.crt) {
        Copy-Item C:\etc\kubernetes\pki\ca.crt -Destination C:\var\lib\Minikube\Certs | Out-Null
        Remove-Item C:\etc\kubernetes\pki\ca.crt | Out-Null
    } else {
        Write-Output "File C:\etc\kubernetes\pki\ca.crt does not exist."
    }
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

    $entry = "`t$IP`tcontrol-plane.minikube.internal"

    $hostsContent = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if ($hostsContent -notmatch [regex]::Escape($entry)) {
        Add-Content -Path $Path -Value "$entry" -Force | Out-Null
    }
}


Export-ModuleMember -Function Start-Minikube
Export-ModuleMember -Function Get-LinuxMasterNodeIP
Export-ModuleMember -Function Set-Flannel
Export-ModuleMember -Function Get-JoinCommand
Export-ModuleMember -Function Invoke-RunCommand
Export-ModuleMember -Function Set-MinikubeFolderError
Export-ModuleMember -Function Add-Host