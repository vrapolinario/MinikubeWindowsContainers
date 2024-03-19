function Install-NSSM {
    $nssmService = Get-WmiObject win32_service | Where-Object {$_.PathName -like '*nssm*'}
    if ($nssmService) {
        Write-Output "NSSM is already installed."
        return
    }

    if (-not (Test-Path -Path "c:\k" -PathType Container)) {
        mkdir "c:\k" | Out-Null
    }
    $arch = "win64"
    $nssmZipFile = "nssm-2.24.zip"
    $nssmUri = "https://k8stestinfrabinaries.blob.core.windows.net/nssm-mirror/$nssmZipFile"
    try {
        Invoke-WebRequest -Uri $nssmUri -OutFile "c:\k\$nssmZipFile" | Out-Null
    }
    catch {
        Throw "NSSM download failed. $_"
    }
    tar.exe C c:\k\ -xf "c:\k\$nssmZipFile" --strip-components 2 */$arch/*.exe | Out-Null

    Write-Output "* NSSM is installed  ..."
}

Export-ModuleMember -Function Install-NSSM