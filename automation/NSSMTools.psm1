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
    curl.exe -L https://k8stestinfrabinaries.blob.core.windows.net/nssm-mirror/nssm-2.24.zip -o nssm.zip
    tar.exe C c:\k\ -xvf .\nssm.zip --strip-components 2 */$arch/*.exe
}

Export-ModuleMember -Function Install-NSSM