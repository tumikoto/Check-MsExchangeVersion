#
# Script to crawl a list of MS Exchange servers via HTTPS, get the build number, and print the corresponding version number
#

Param(
	[parameter(Mandatory=$false)]
	[String]$TargetFile
)

# Usage
If (!($TargetFile) -or !(Test-Path $TargetFile)) {
	Write-Host "Usage:"
	Write-Host "`tCheck-MsExchangeVersion.ps1 -TargetFile <filePath>"
	Write-Host " "
	Write-Host "Example:"
	Write-Host "`tCheck-MsExchangeVersion.ps1 -TargetFile exchange_servers.txt"
	Exit
}

# Parse build number to Exchange major version
function Get-ExchangeMajorVersion {
    param (
        [string]$buildNumber
    )
    $majorVersion = "Unknown"
    switch -Wildcard ($buildNumber) {
        "8.0.*" { $majorVersion = "Exchange 2007" }
        "8.1.*" { $majorVersion = "Exchange 2007 SP1" }
        "8.2.*" { $majorVersion = "Exchange 2007 SP2" }
        "8.3.*" { $majorVersion = "Exchange 2007 SP3" }
        "14.0.*" { $majorVersion = "Exchange 2010" }
		"14.1.*" { $majorVersion = "Exchange 2010 SP1" }
		"14.2.*" { $majorVersion = "Exchange 2010 SP2" }
        "14.3.*" { $majorVersion = "Exchange 2010 SP3" }
        "15.0.*" { $majorVersion = "Exchange 2013" }
        "15.1.*" { $majorVersion = "Exchange 2016" }
        "15.2.*" { $majorVersion = "Exchange 2019" }
    }
    return $majorVersion
}

# Check if the first build number >= the second
function Compare-Version {
    param (
        [string]$version1,
        [string]$version2
    )
    $v1 = $version1.Split('.')
    $v2 = $version2.Split('.')
    for ($i = 0; $i -lt $v1.Length; $i++) {
        if ([int]$v1[$i] -lt [int]$v2[$i]) {
            return $false
        }
        elseif ([int]$v1[$i] -gt [int]$v2[$i]) {
            return $true
        }
    }
    return $true
}

# Loop through target URIs in file and process each
$scanResults = @()
$targetlist = Get-Content -path $TargetFile
foreach ($target in $targetlist) {

	# Try to crawl the OWA
	try {
		$response = Invoke-WebRequest -Method GET -Uri ($target + "/owa") -SkipCertificateCheck -ErrorAction Stop
	} catch {
		# Web error
		Write-Host -Foregroundcolor Yellow [+] Target $target build number could not be detected`, request error
		$error.
		Continue
	}

	# Detect hybrid via redirect to o365
	if ($response.BaseResponse.RequestMessage.RequestUri.Host -eq "login.microsoftonline.com") {
		Write-Host -Foregroundcolor Yellow [+] Target $target threw redirect to Office 365`, Hybrid deployment`, skipping
		Continue
	}

	# Parse response to find link to Exchange favicon
	$favicon = $response.content -split "`r`n" | where {$_ -match "themes/resources/favicon.ico"} | Select -first 1

	# If favicon link found
	if ($favicon) {
		
		# Get build number from favicon path
		$build = ($favicon).Split("/")[3]
		
		# Get version from build number
		$version = Get-ExchangeMajorVersion -buildNumber $build
		
		# Build results obj
		$scanResult = New-Object -TypeName PSObject
		Add-Member -InputObject $scanResult -MemberType NoteProperty -Name "Target" -Value $target
		Add-Member -InputObject $scanResult -MemberType NoteProperty -Name "Version" -Value $version
		Add-Member -InputObject $scanResult -MemberType NoteProperty -Name "Build" -Value $build
		$scanResults += $scanResult

		Continue
	}

	# Couldnt get build from favicon
	Write-Host -Foregroundcolor Yellow [+] Target $target build number could not be detected`, parsed response with no results
}

# Print results to console
$scanResults | ft

