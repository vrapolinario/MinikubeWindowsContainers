function Get-LatestToolVersion($repository) {
    try {
        $uri = "https://api.github.com/repos/$repository/releases/latest"
        $response = Invoke-WebRequest -Uri $uri
        $version = ($response.content  | ConvertFrom-Json).tag_name
        return $version.TrimStart("v")
    }
    catch {
        Throw "Could not get $repository version. $_"
    }
}