Import-Module -Name "$PSScriptRoot\k8Tools.psm1" -Force

function Run {
    param (
        [string]$VMName,
        [string]$UserName,
        [string]$Pass
    ) 

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
    
        # Initialize Windows Node
        . "$UncompressedFolderPath\automation\InitNode.ps1"

        Exit-PSSession
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock


    $commandString = "minikube ip"
    $IP = Invoke-Expression -Command $commandString
    Write-Host "$IP --- IP"

    $ScriptBlock = { 
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]
            $IP
        )
        $UncompressedFolderPath = "C:\Users\Administrator\Documents\MinikubeWindowsContainers"

        Import-Module -Name "$UncompressedFolderPath\automation\MinikubeTools.psm1" -Force

        # Set Host File
        #. "$UncompressedFolderPath\automation\SetHost.ps1"
        Add-Host -IP $IP

        Exit-PSSession
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $IP

    Get-Kubeadm

    $JoinCommand = Get-JoinCommand

    Invoke-Expression $JoinCommand

    Set-MinikubeFolderError

    Invoke-Expression $JoinCommand

    # windows node successfully joined in the cluster
    & kubectl get nodes -o wide
}


