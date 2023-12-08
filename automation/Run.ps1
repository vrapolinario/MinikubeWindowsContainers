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

    $LocalScriptsPath = $PWD
    $CompressedFilePath = "$LocalScriptsPath\MinikubeWindowsContainers.zip" 

    Compress-Archive -Path $LocalScriptsPath -DestinationPath $CompressedFilePath -Force

    $RemoteScriptsPath = "C:\Users\Administrator\Documents" 

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
    
        # Run the main script
        . "$UncompressedFolderPath\automation\Main.ps1"
    }

    Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock
}


