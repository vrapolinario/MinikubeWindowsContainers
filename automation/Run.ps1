Import-Module -Name "$PSScriptRoot\k8Tools.psm1" -Force
Import-Module -Name "$PSScriptRoot\ContainerdTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\MinikubeTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\NSSMTools.psm1" -Force

function Run {
    param (
        [string]$VMName,
        [string]$UserName,
        [string]$Pass,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$KubernetesVersion
    ) 

    # create and configure a new minikube cluster 
    Write-Output "* Creating and configuring a new minikube cluster ..."
    & minikube start --driver=hyperv --hyperv-virtual-switch=$SwitchName --nodes=2 --cni=flannel --container-runtime=containerd --kubernetes-version=$KubernetesVersion
    # & minikube start --driver=hyperv --hyperv-virtual-switch=$SwitchName --memory=4096 --cpus=2 --kubernetes-version=v1.20.2 --network-plugin=cni --cni=flannel --container-runtime=containerd --disk-size=15GB --wait=false >> logs
    Write-Output "* Minikube cluster is created and configured  ..."
    # Prepare the Linux nodes for Windows-specific Flannel CNI configuration
    # at the moment we are assuming that you only have two linux nodes named minikube and minikube-m02
    & minikube ssh "sudo sysctl net.bridge.bridge-nf-call-iptables=1 && exit" >> logs
    & minikube ssh -n minikube-m02 "sudo sysctl net.bridge.bridge-nf-call-iptables=1 && exit" >> logs
    Write-Output "* Linux nodes are ready for Windows-specific Flannel CNI configuration  ..."


    # configure Flannel CNI for Windows
    # make sure the flannel daemon set is restarted to reflect the new Windows-specific configuration
    & kubectl apply -f "..\kube-flannel.yaml" >> logs
    & kubectl rollout restart ds kube-flannel-ds -n kube-flannel >> logs
    & kubectl get pods -A >> logs
    Write-Output "* Flannel CNI for Windows is configured and the daemon set is restarted  ..."


    Enter-PSSession -VMName $VMName -Credential $Credential

    # Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {Get-Culture} 

    $CurrrentDirectory = $PWD
    $LocalScriptsPath = Split-Path -Path $CurrrentDirectory -Parent
    $CompressedFilePath = "$LocalScriptsPath\MinikubeWindowsContainers.zip" 

    # 'auto-install.iso' is not being compressed since another process will be using it
    # hack way of compressing the error but it works, needs exploration
    Compress-Archive -Path $LocalScriptsPath -DestinationPath $CompressedFilePath -Force 2>$null

    $RemoteScriptsPath = "C:\Users\Administrator\Documents" 

    $session = New-PSSession -VMName $VMName -Credential $Credential
    
    Copy-Item -Path $CompressedFilePath -Destination $RemoteScriptsPath -Force -ToSession $Session  

    $ScriptBlock = { 
        $CompressedFilePath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers.zip"
        $UncompressedFolderPath = "C:\Users\Administrator\Documents"
        Expand-Archive -Path $CompressedFilePath -DestinationPath $UncompressedFolderPath -Force
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock 

    $ScriptBlock = { 
        $UncompressedFolderPath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers"
        Import-Module -Name "$UncompressedFolderPath\automation\ContainerdTools.psm1" -Force

        Install-Containerd
        Initialize-ContainerdService
        Start-ContainerdService

        Exit-PSSession
    }
    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock

    $ScriptBlock = { 
        $UncompressedFolderPath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers"
        Import-Module -Name "$UncompressedFolderPath\automation\NSSMTools.psm1" -Force

        Install-NSSM

        Exit-PSSession
    }
    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock

    $ScriptBlock = { 
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]
            $KubernetesVersion
        )
        $UncompressedFolderPath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers"
        Import-Module -Name "$UncompressedFolderPath\automation\k8Tools.psm1" -Force

        Install-Kubelet -KubernetesVersion $KubernetesVersion
        Set-Port

        Exit-PSSession
    }
    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $KubernetesVersion


    $commandString = "minikube ip"
    $IP = Invoke-Expression -Command $commandString 

    $ScriptBlock = { 
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]
            $IP
        )
        $UncompressedFolderPath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers"

        Import-Module -Name "$UncompressedFolderPath\automation\MinikubeTools.psm1" -Force

        Add-Host -IP $IP

        Exit-PSSession
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $IP
    

    $JoinCommand = Get-JoinCommand -KubernetesVersion $KubernetesVersion

    $ScriptBlock = { 
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]
            $JoinCommand,
            
            [Parameter()]
            [string]
            $KubernetesVersion
        )
        $UncompressedFolderPath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers"

        Import-Module -Name "$UncompressedFolderPath\automation\MinikubeTools.psm1" -Force
        Import-Module -Name "$UncompressedFolderPath\automation\k8Tools.psm1" -Force

        
        Get-Kubeadm -KubernetesVersion $KubernetesVersion


        Set-Location -Path "C:\k"

        Write-Output "* Joining the Windows node to the cluster ..."

        Invoke-Expression "$JoinCommand >> logs 2>&1"

        Set-MinikubeFolderError

        Invoke-Expression "$JoinCommand >> logs 2>&1"

        Exit-PSSession
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $JoinCommand, $KubernetesVersion

    # configure flannel and kube-proxy on the windows node
    & kubectl apply -f "..\flannel-overlay.yaml" >> logs
    & kubectl apply -f "..\kube-proxy.yaml" >> logs

    Write-Output "* Waiting for the node to come to a ready state ..."
    Start-Sleep -Seconds 40

    # validate windows node successfully join
    & kubectl get nodes -o wide >> logs
    
    # check the status of the windows node
    & kubectl get nodes -o wide
    Write-Output "* Windows node is successfully joined and configured  ..."

}