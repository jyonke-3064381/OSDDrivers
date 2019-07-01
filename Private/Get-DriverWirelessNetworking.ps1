function Get-DriverWirelessNetworking {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [string]$DownloadPath,
        [string]$PackagePath
    )

    Write-Host $DownloadPath
    #===================================================================================================
    #   Defaults WirelessNetworking
    #===================================================================================================
    $Global:OSDInfoUrl = $null
    $Global:OSDDownloadUrl = 'https://downloadcenter.intel.com/product/59485/Wireless-Networking'
    $Global:OSDPageUrl = $null
    $Global:OSDDownloadFileName = ''
    $Global:OSDDownloadMethod = 'BITS'
    $Global:DriverClass = 'Net'
    $Global:DriverClassGUID = '{4D36E972-E325-11CE-BFC1-08002BE10318}'
    #===================================================================================================
    #   OSDDownloadUrl
    #===================================================================================================
    Write-Host "Validating $OSDDownloadUrl" -ForegroundColor Cyan
    Write-Host ""
    #===================================================================================================
    #   Get DownloadPages
    #===================================================================================================
    $DownloadPages = @()
    $DownloadPages = (Invoke-WebRequest -Uri "$OSDDownloadUrl").Links
    #===================================================================================================
    #   Filter Results
    #===================================================================================================
    $DownloadPages = $DownloadPages | Select-Object -Property innerText, href
    $DownloadPages = $DownloadPages | Where-Object {$_.innerText -notlike "*exe*"}
    $DownloadPages = $DownloadPages | Where-Object {$_.innerText -notlike "*bluetooth*"}
    
    $DownloadPages = $DownloadPages | Where-Object {$_.href -like "/download*"}
    foreach ($Link in $DownloadPages) {
        $Link.innerText = ($Link).innerText.replace('][',' ')
        $Link.innerText = $Link.innerText -replace '[[]', ''
        $Link.innerText = $Link.innerText -replace '[]]', ''
        $Link.innerText = $Link.innerText -replace '[®]', ''
        $Link.innerText = $Link.innerText -replace '[*]', ''
    }

    foreach ($Link in $DownloadPages) {
        $Link.href = "https://downloadcenter.intel.com$($Link.href)"
    }
    #===================================================================================================
    #   Exclude DownloadPages
    #===================================================================================================
    #===================================================================================================
    #   Return Downloads
    #===================================================================================================
    $UrlDownloads = @()
    $OnlineDrivers = @()
    $OnlineDrivers = foreach ($Link in $DownloadPages) {
        $DriverName = $($Link.innerText)
        Write-Host "Intel PROSet Wireless Software and Drivers for IT Admins $DriverName"

        $DriverPage = $($Link.href)
        Write-Host "$DriverPage" -ForegroundColor DarkGray
        #===================================================================================================
        #   Intel WebRequest
        #===================================================================================================
        $DriverPageContent = Invoke-WebRequest -Uri $DriverPage -Method Get

        $DriverHTML = $DriverPageContent.ParsedHtml.childNodes | Where-Object {$_.nodename -eq 'HTML'} 
        $DriverHEAD = $DriverHTML.childNodes | Where-Object {$_.nodename -eq 'HEAD'}
        $DriverMETA = $DriverHEAD.childNodes | Where-Object {$_.nodename -like "meta*"}

        $DriverVersion = $DriverMETA | Where-Object {$_.name -eq 'DownloadVersion'} | Select-Object -ExpandProperty Content
        $DriverType = $DriverMETA | Where-Object {$_.name -eq 'DownloadType'} | Select-Object -ExpandProperty Content
        $DriverCompatibility = $DriverMETA | Where-Object {$_.name -eq 'DownloadOSes'} | Select-Object -ExpandProperty Content
        Write-Host "DriverCompatibility: $DriverCompatibility" -ForegroundColor DarkGray
        #===================================================================================================
        #   Driver Filter
        #===================================================================================================
        $UrlDownloads = ($DriverPageContent).Links
        $UrlDownloads = $UrlDownloads | Where-Object {$_.'data-direct-path' -like "*.zip" -or $_.'data-direct-path' -like "*.exe"}
        $UrlDownloads = $UrlDownloads | Where-Object {$_.innerText -notlike "*WinXP*"}
        $UrlDownloads = $UrlDownloads | Where-Object {$_.innerText -notlike "*WinVista*"}
        $UrlDownloads = $UrlDownloads | Where-Object {$_.innerText -notlike "*Win8*"}
        #===================================================================================================
        #   Driver Details
        #===================================================================================================
        foreach ($UrlDownload in $UrlDownloads) {
            $OSVersionMin = $null
            $OSVersionMax = $null
            $OSArch = $null
            $OnlineDriver = $UrlDownload.'data-direct-path'

            if ($null -eq $OSArch) {
                if (($OnlineDriver -like "*win64*") -or ($OnlineDriver -like "*Driver64*") -or ($OnlineDriver -like "*64_*") -or ($DriverPage -like "*64-Bit*")) {
                    $OSArch = 'x64'
                } else {
                    $OSArch = 'x86'
                }
            }

            if ($OnlineDriver -like "*Win7*") {
                $OSVersionMin = '6.1'
                $OSVersionMax = '6.1'
                $DriverName = "$DriverGroup $DriverVersion $OSArch Win7"
            }
            if ($OnlineDriver -like "*Win8.1*") {
                $OSVersionMin = '6.3'
                $OSVersionMax = '6.3'
                $DriverName = "$DriverGroup $DriverVersion $OSArch Win8.1"
            }
            if ($OnlineDriver -like "*Win10*") {
                $OSVersionMin = '10.0'
                $OSVersionMax = '10.0'
                $DriverName = "$DriverGroup $DriverVersion $OSArch Win10"
            }
            $DriverCabFile = "$DriverName.cab"
            $DriverZipFile = "$DriverName.zip"
            #===================================================================================================
            #   Driver Status
            #===================================================================================================
            $OSDDriverStatus = $null
            if (Test-Path "$DownloadPath\$DriverZipFile") {$OSDDriverStatus = 'Downloaded'}
            if (Test-Path "$DownloadPath\$DriverCabFile") {$OSDDriverStatus = 'Packaged'}
            if (Test-Path "$PackagePath\$DriverCabFile") {$OSDDriverStatus = 'Published'}
            #===================================================================================================
            #   Create Object
            #===================================================================================================
            $ObjectProperties = @{
                DriverGroup         = $DriverGroup
                DriverClass         = $DriverClass
                OSDDriverStatus        = $OSDDriverStatus
                LastUpdated         = $DriverMETA | Where-Object {$_.name -eq 'LastUpdate'} | Select-Object -ExpandProperty Content
                DriverName          = $DriverName
                DriverVersion       = $DriverVersion
                OSArch              = $OSArch
                OSVersionMin        = $OSVersionMin
                OSVersionMax        = $OSVersionMax
                Description         = $DriverMETA | Where-Object {$_.name -eq 'Description'} | Select-Object -ExpandProperty Content
                DriverClassGUID     = $DriverClassGUID
                DriverPage          = $DriverPage
                OnlineDriver      = $OnlineDriver
                DriverZipFile       = $DriverZipFile
                DriverCabFile       = $DriverCabFile
            }
            New-Object -TypeName PSObject -Property $ObjectProperties
        }
    }
    Write-Host "Exporting $env:Temp\OSDDrivers $DriverGroup.xml" -ForegroundColor Cyan
    $OnlineDrivers | Export-Clixml "$env:Temp\OSDDrivers $DriverGroup.xml" -Force
    $OnlineDrivers = $OnlineDrivers | Sort-Object -Property LastUpdated -Descending | Select-Object DriverGroup,DriverClass,OSDDriverStatus,LastUpdated,DriverName,DriverVersion,OSArch,OSVersionMin,OSVersionMax,DriverClassGUID,Description,OnlineDriver,DriverPage,DriverZipFile,DriverCabFile

    $OnlineDrivers | Export-Clixml "$DownloadPath\OSDDrivers $DriverGroup.xml"
    if ($PackagePath) {
        $OnlineDrivers | Export-Clixml "$PackagePath\OSDDrivers $DriverGroup.xml"
    }

    $OnlineDrivers = $OnlineDrivers | Out-GridView -PassThru -Title 'Select Driver Downloads to Package and press OK'
    #Return $OnlineDrivers
    
    #===================================================================================================
    #   Download
    #===================================================================================================
    foreach ($SelectedOnlineDriver in $OnlineDrivers) {
        $OSDDriverStatus = $($SelectedOnlineDriver.OSDDriverStatus)
        $DriverGroup = $($SelectedOnlineDriver.DriverGroup)
        $DriverClass = $($SelectedOnlineDriver.DriverClass)
        $DriverClassGUID = $($SelectedOnlineDriver.DriverClassGUID)
        $OnlineDriver = $($SelectedOnlineDriver.OnlineDriver)
        $DriverOSArch = $($SelectedOnlineDriver.OSArch)
        $DriverOSVersionMin = $($SelectedOnlineDriver.OSVersionMin)
        $DriverOSVersionMax = $($SelectedOnlineDriver.OSVersionMax)

        $DriverCabFile = $($SelectedOnlineDriver.DriverCabFile)
        $DriverZipFile = $($SelectedOnlineDriver.DriverZipFile)
        $DriverDirectory = ($DriverCabFile).replace('.cab','')

        Write-Host "OnlineDriver: $OnlineDriver" -ForegroundColor Cyan
        Write-Host "DriverZipFile: $DownloadPath\$DriverZipFile" -ForegroundColor Gray

        if (Test-Path "$PackagePath\$DriverCabFile") {
            Write-Warning "$PackagePath\$DriverCabFile ... Exists!"
        } elseif (Test-Path "$DownloadPath\$DriverZipFile") {
            Write-Warning "$DownloadPath\$DriverZipFile ... Exists!"
        } else {
            Start-BitsTransfer -Source "$OnlineDriver" -Destination "$DownloadPath\$DriverZipFile"
        }
        if ($PackagePath) {
            #===================================================================================================
            #   Expand Zip
            #   Need to add logic to unzip if necessary
            #===================================================================================================
            if (-not(Test-Path "$PackagePath\$DriverCabFile")) {
                Write-Host "DriverDirectory: $DownloadPath\$DriverDirectory" -ForegroundColor Gray

                if (Test-Path "$DownloadPath\$DriverDirectory") {
                    Write-Warning "$DownloadPath\$DriverDirectory ... Removing!"
                    Remove-Item -Path "$DownloadPath\$DriverDirectory" -Recurse -Force | Out-Null
                }

                Write-Host "Expanding $DownloadPath\$DriverZipFile ..." -ForegroundColor Gray
                Expand-Archive -Path "$DownloadPath\$DriverZipFile" -DestinationPath "$DownloadPath\$DriverDirectory" -Force
            }

            #===================================================================================================
            #   OSDDriverPnp
            #===================================================================================================
            if (Test-Path "$DownloadPath\$DriverDirectory") {
                $OSDDriverPnp = (New-OSDDriverPnp -DriverDirectory "$DownloadPath\$DriverDirectory" -DriverClass $DriverClass)
            }
            #===================================================================================================
            #   Create CAB
            #===================================================================================================
            if ( -not (Test-Path "$DownloadPath\$DriverCabFile")) {
                Write-Verbose "Creating $DownloadPath\$DriverCabFile ..." -Verbose
                New-OSDDriverCab -SourceDirectory "$DownloadPath\$DriverDirectory" -ShowOutput
            }
            #===================================================================================================
            #   Copy CAB
            #===================================================================================================
            if ( -not (Test-Path "$PackagePath\$DriverCabFile")) {
                Write-Verbose "Copying $DownloadPath\$DriverCabFile to $PackagePath\$DriverCabFile ..." -Verbose
                Copy-Item -Path "$DownloadPath\$DriverCabFile" -Destination "$PackagePath" -Force | Out-Null
            }
            #===================================================================================================
            #   OSDDriverTask
            #===================================================================================================
            Write-Host "Creating OSDDriverTask $DriverOSArch $DriverOSVersionMin $DriverOSVersionMax ..." -ForegroundColor Gray
            New-OSDDriverTask -DriverCabFile "$PackagePath\$DriverCabFile" -OSArch $DriverOSArch -OSVersionMin $DriverOSVersionMin -OSVersionMax $DriverOSVersionMax
            if (Test-Path "$OSDDriverPnp") {
                Copy-Item "$OSDDriverPnp" "$PackagePath" -Force
            }
        }
    }
}