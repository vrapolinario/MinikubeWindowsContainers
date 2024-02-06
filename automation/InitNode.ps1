Import-Module -Name "$PSScriptRoot\ContainerdTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\k8Tools.psm1" -Force
Import-Module -Name "$PSScriptRoot\MinikubeTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\NSSMTools.psm1" -Force

Install-Containerd
Initialize-ContainerdService
Start-ContainerdService
Write-Output "* Containerd is installed and the service is started  ..."
Install-NSSM
Write-Output "* NSSM is installed  ..."
Install-Kubelet
Write-Output "* Kubelet is installed and the service is started  ..."
Set-Port
