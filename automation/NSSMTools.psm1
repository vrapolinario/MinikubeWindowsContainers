function Install-NSSM {
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        [parameter(HelpMessage = "NSSM version to use. Default 2.24")]
        $Version = "2.24",

        [String]
        [parameter(HelpMessage = "Architecture ")]
        $Arch = "win64",
        
        [String]
        [parameter(HelpMessage = "Path to download files.")]
        $DownloadPath = "c:\k"
    )

    $Version = $Version.TrimStart('v')
    
    $nssmTarFile = "nssm-${version}.zip"
    $Uri = "https://k8stestinfrabinaries.blob.core.windows.net/nssm-mirror/$($nssmTarFile)"
    $params = @{
        Feature      = "nssm"
        Version      = $Version
        Uri          = $Uri
        InstallPath  = $InstallPath
        DownloadPath = "$DownloadPath\$containerdTarFile"
        EnvPath      = $EnvPath
        cleanup      = $true
    }

    Write-Output "Downloading and installing Containerd at $InstallPath"
    Invoke-WebRequest -Uri $Uri -OutFile $DownloadPath\$containerdTarFile -Verbose
    Install-RequiredFeature @params

    Write-Output "Containerd successfully installed at $InstallPath"
    containerd.exe -v

    Write-Output "For containerd usage: run 'containerd -h'"
}