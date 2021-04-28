Param(
		[parameter(Mandatory=$true)]
		[String]$targetlistfile
	)

  If (!($targetlistfile)) {
    Write-Host Usage:
    Write-Host  Check-MsExchangeVersion.ps1 -TargetListFile <path to file containing list of URIs>
    Write-Host " "
    Write-Host Example:
    Write-Host  Check-MsExchangeVersion.ps1 -TargetListFile "exchange_servers.txt"
    Exit
  }

	$targetlist = Get-Content -path $targetlistfile

	foreach ($target in $targetlist) {

	try {
		$response = Invoke-WebRequest -Method GET -Uri ($target + "/owa") -SkipCertificateCheck -ErrorAction Stop
	} catch {
		Write-Host -Foregroundcolor Red [+] Target $target version could not be detected`, request error
		Continue
	}
	
	if ($response.BaseResponse.RequestMessage.RequestUri.Host -eq "login.microsoftonline.com") {
		Write-Host -Foregroundcolor Yellow [+] Target $target threw redirect to Office 365`, Hybrid deployment
		Continue
	}
	
	$favicon = $response.content -split "`r`n" | where {$_ -match "themes/resources/favicon.ico"} | Select -first 1
	
	if ($favicon) {
		$version = ($favicon).Split("/")[3]
		Write-Host -Foregroundcolor Green [+] Target $target shows version $version
		Continue
	}
	
	Write-Host -Foregroundcolor Red [+] Target $target version could not be detected`, parsed response with no results
	}
