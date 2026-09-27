# Zips a staged directory tree into a proper ZIP archive with forward-slash entry
# names, for use as the PowerShell packaging fallback in substrait-deploy.sh (used
# on Windows machines with no `zip` binary on PATH).
#
# NOT Compress-Archive: on Windows PowerShell 5.1 (and the underlying
# System.IO.Compression.ZipFile on .NET Framework more generally, including
# ZipFile.CreateFromDirectory), zip entries are written with the OS path separator
# (backslash) instead of the ZIP-spec forward slash -- e.g. a file at
# "cicd/Dockerfile.backend" ends up as a zip entry literally named
# "cicd\Dockerfile.backend" (one flat filename containing a backslash), not a
# "cicd/" directory containing "Dockerfile.backend". Server-side unzip (almost
# always Linux) doesn't treat "\" as a path separator, so it never finds the file
# at the expected nested path -- deploys fail contract validation with a false
# "no backend Dockerfile found" even though the file is right there.
#
# This script builds the archive entry-by-entry instead, computing each entry's
# relative path itself and normalizing it to forward slashes before adding it.
param(
    [Parameter(Mandatory = $true)][string]$SrcRoot,
    [Parameter(Mandatory = $true)][string]$DestZip
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (Test-Path $DestZip) { Remove-Item $DestZip -Force }

# $SrcRoot may arrive as a short (8.3) path alias -- e.g. from a bash-side
# `cygpath -w` on a dotted Windows username -- while Get-ChildItem's FullName
# always comes back long-form. Resolve to the long form first, or the prefix
# strip below silently computes wrong (garbage) relative paths instead of
# failing loudly.
$srcRootFull = (Get-Item -LiteralPath $SrcRoot).FullName.TrimEnd('\')

$zip = [System.IO.Compression.ZipFile]::Open($DestZip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem -Path $srcRootFull -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($srcRootFull.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $zip.Dispose()
}
