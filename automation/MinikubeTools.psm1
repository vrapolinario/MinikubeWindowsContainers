Import-Module -Name "$PSScriptRoot\k8Tools.psm1" -Force

function Get-JoinCommand {
    param (
        [string]
        $KubernetesVersion
    )
    $JoinCommand = (minikube ssh "cd /var/lib/minikube/binaries/v$KubernetesVersion/ && sudo ./kubeadm token create --print-join-command") 
    $outputString = $JoinCommand -replace 'kubeadm', '.\kubeadm.exe'
    $outputString += ' --cri-socket "npipe:////./pipe/containerd-containerd"'
    $outputString += ' --v=5'
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

Export-ModuleMember -Function Get-JoinCommand
Export-ModuleMember -Function Set-MinikubeFolderError
Export-ModuleMember -Function Add-Host