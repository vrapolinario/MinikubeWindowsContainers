Import-Module -Name "$PSScriptRoot\ContainerdTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\k8Tools.psm1" -Force
Import-Module -Name "$PSScriptRoot\MinikubeTools.psm1" -Force
Import-Module -Name "$PSScriptRoot\NSSMTools.psm1" -Force

function Run {
    param (
        [string]$VMName,
        [string]$UserName,
        [string]$Pass
    ) 

    # configure Flannel CNI for Windows
    # make sure the flannel daemon set is restarted to reflect the new Windows-specific configuration
    & kubectl apply -f "..\kube-flannel.yaml"
    & kubectl rollout restart ds kube-flannel-ds -n kube-flannel 
    & kubectl get pods -A

    $SecurePassword = ConvertTo-SecureString -String $Pass -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword

    Enter-PSSession -VMName $VMName -Credential $Credential

    # Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {Get-Culture} 

    $CurrrentDirectory = $PWD
    $LocalScriptsPath = Split-Path -Path $CurrrentDirectory -Parent
    $CompressedFilePath = "$LocalScriptsPath\MinikubeWindowsContainers.zip" 

    Compress-Archive -Path $LocalScriptsPath -DestinationPath $CompressedFilePath -Force

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
        Import-Module -Name "$UncompressedFolderPath\automation\k8Tools.psm1" -Force
        Import-Module -Name "$UncompressedFolderPath\automation\MinikubeTools.psm1" -Force
        Import-Module -Name "$UncompressedFolderPath\automation\NSSMTools.psm1" -Force
    
        . "$UncompressedFolderPath\automation\InitNode.ps1"

        Exit-PSSession
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock


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
    

    $JoinCommand = Get-JoinCommand

    $ScriptBlock = { 
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]
            $JoinCommand
        )
        $UncompressedFolderPath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers"

        Import-Module -Name "$UncompressedFolderPath\automation\MinikubeTools.psm1" -Force
        Import-Module -Name "$UncompressedFolderPath\automation\k8Tools.psm1" -Force

        Get-Kubeadm

        Invoke-Expression $JoinCommand

        Set-MinikubeFolderError

        Invoke-Expression $JoinCommand

        Exit-PSSession
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $JoinCommand

    # validate windows node successfully join
    & kubectl get nodes -o wide

    # configure flannel and kube-proxy on the windows node
    & kubectl apply -f "..\flannel-overlay.yaml"
    & kubectl apply -f "..\kube-proxy.yaml"

    # check the status of the windows node
    & kubectl get nodes -o wide

}