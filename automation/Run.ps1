Import-Module -Name "$PSScriptRoot\ContainerdTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\k8Tools.psm1" -Force
Import-Module -Name "$PSScriptRoot\MinikubeTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\NSSMTools.psm1" -Force

Install-Containerd
Initialize-ContainerdService
Start-ContainerdService
Install-NSSM
Install-Kubelet
Set-Port

$IP = minikube ip  
$Path = $Path = "C:\Windows\System32\drivers\etc\hosts"

Add-Host -IP $IP -Path $Path

Get-Kubeadm


$JoinCommand = Get-JoinCommand

Invoke-Expression $JoinCommand

Set-MinikubeFolderError

Invoke-Expression $JoinCommand

# windows node successfully joined in the cluster
& kubectl get nodes -o wide