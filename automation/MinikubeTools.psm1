function Start-Minikube {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $SwitchName = "External VM Switch"
    )
    
    minikube start --driver=hyperv --hyperv-virtual-switch=$SwitchName --nodes=2 --cni=flannel --container-runtime=containerd
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