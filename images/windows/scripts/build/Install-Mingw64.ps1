################################################################################
##  File:  Install-Mingw64.ps1
##  Desc:  Install GNU tools for Windows
################################################################################

if (Test-IsWin19) {
    # If Windows 2019, install version 8.1.0 form sourceforge
    $baseUrl = "https://sourceforge.net/projects/mingw-w64/files"

    $("mingw32", "mingw64") | ForEach-Object {
        if ($_ -eq "mingw32") {
            $url = "https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v11.0.0.tar.bz2?ts=gAAAAABm-t-OC99JEhgzCDOIw-0zSeQ0vgDlPUNijEfbKu5guIJbT2t36s4VSvJR_0cbWNxoO45GhSFYZlrXdQPiT7wy_Sl3Zw%3D%3D&r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fmingw-w64%2Ffiles%2Flatest%2Fdownload"
            $sha256sum = 'adb84b70094c0225dd30187ff995e311d19424b1eb8f60934c60e4903297f946'
        } elseif ($_ -eq "mingw64") {
            $url = "$baseUrl/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/8.1.0/threads-posix/seh/x86_64-8.1.0-release-posix-seh-rt_v6-rev0.7z/download"
            $sha256sum = '853970527b5de4a55ec8ca4d3fd732c00ae1c69974cc930c82604396d43e79f8'
        } else {
            throw "Unknown architecture $_"
        }

        $packagePath = Invoke-DownloadWithRetry $url
        Test-FileChecksum -Path $packagePath -ExpectedSHA256Sum $sha256sum
        Expand-7ZipArchive -Path $packagePath -DestinationPath "C:\"

        # Make a copy of mingw-make.exe to make.exe, which is a more discoverable name
        # and so the same command line can be used on Windows as on macOS and Linux
        $path = "C:\$_\bin\mingw32-make.exe" | Get-Item
        Copy-Item -Path $path -Destination (Join-Path $path.Directory 'make.exe')
    }
    
    Add-MachinePathItem "C:\mingw64\bin"

}

if (Test-IsWin22) {
    # If Windows 2022, install version specified in the toolset
    $version = (Get-ToolsetContent).mingw.version
    $runtime = (Get-ToolsetContent).mingw.runtime

    $("mingw32", "mingw64") | ForEach-Object {
        if ($_ -eq "mingw32") {
            $arch = "i686"
            $threads = "posix"
            $exceptions = "dwarf"
        } elseif ($_ -eq "mingw64") {
            $arch = "x86_64"
            $threads = "posix"
            $exceptions = "seh"
        } else {
            throw "Unknown architecture $_"
        }

        $url = Resolve-GithubReleaseAssetUrl `
            -Repo "niXman/mingw-builds-binaries" `
            -Version "$version" `
            -Asset "$arch-*-release-$threads-$exceptions-$runtime-*.7z"

        $packagePath = Invoke-DownloadWithRetry $url
        Expand-7ZipArchive -Path $packagePath -DestinationPath "C:\"

        # Make a copy of mingw-make.exe to make.exe, which is a more discoverable name
        # and so the same command line can be used on Windows as on macOS and Linux
        $path = "C:\$_\bin\mingw32-make.exe" | Get-Item
        Copy-Item -Path $path -Destination (Join-Path $path.Directory 'make.exe')
    }

    Add-MachinePathItem "C:\mingw64\bin"
}

Invoke-PesterTests -TestFile "Tools" -TestName "Mingw64"
