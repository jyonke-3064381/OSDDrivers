function Get-DriverWirelessIntel {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [string]$DownloadPath,
        [string]$PackagePath
    )

    Write-Host $DownloadPath
    #===================================================================================================
    #   Defaults WirelessIntel
    #===================================================================================================
    $Global:OSDInfoUrl = $null
    $Global:OSDDownloadUrl = 'https://www.intel.com/content/www/us/en/support/articles/000017246/network-and-i-o/wireless-networking.html'
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
    $DownloadPages = $DownloadPages | Where-Object {$_.href -like "*downloadcenter.intel.com/download*"}
    $DownloadPages = $DownloadPages | Select-Object -First 1
    #===================================================================================================
    #   Exclude DownloadPages
    #===================================================================================================
    #===================================================================================================
    #   Return Downloads
    #===================================================================================================
    $UrlDownloads = @()
    $DriverDownloads = @()
    $DriverDownloads = foreach ($Link in $DownloadPages) {
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
        $UrlDownloads = $UrlDownloads | Where-Object {$_.'data-direct-path' -like "*.zip"}
        $UrlDownloads = $UrlDownloads | Where-Object {$_.innerText -notlike "*wifi*all*"}
        $UrlDownloads = $UrlDownloads | Where-Object {$_.innerText -notlike "*proset*"}
        #===================================================================================================
        #   Driver Details
        #===================================================================================================
        foreach ($UrlDownload in $UrlDownloads) {
            $OSVersionMin = $null
            $OSVersionMax = $null
            $OSArch = $null
            $DriverDownload = $UrlDownload.'data-direct-path'

            if ($null -eq $OSArch) {
                if (($DriverDownload -like "*win64*") -or ($DriverDownload -like "*Driver64*") -or ($DriverDownload -like "*64_*") -or ($DriverPage -like "*64-Bit*")) {
                    $OSArch = 'x64'
                } else {
                    $OSArch = 'x86'
                }
            }

            if ($DriverDownload -like "*Win7*") {
                $OSVersionMin = '6.1'
                $OSVersionMax = '6.1'
                $DriverName = "$DriverGroup $DriverVersion $OSArch Win7"
            }
            if ($DriverDownload -like "*Win8.1*") {
                $OSVersionMin = '6.3'
                $OSVersionMax = '6.3'
                $DriverName = "$DriverGroup $DriverVersion $OSArch Win8.1"
            }
            if ($DriverDownload -like "*Win10*") {
                $OSVersionMin = '10.0'
                $OSVersionMax = '10.0'
                $DriverName = "$DriverGroup $DriverVersion $OSArch Win10"
            }
            $DriverCab = "$DriverName.cab"
            $DriverZipFileName = "$DriverName.zip"
            #===================================================================================================
            #   Driver Status
            #===================================================================================================
            $OSDDriverStatus = $null
            if (Test-Path "$DownloadPath\$DriverZipFileName") {$OSDDriverStatus = 'Downloaded'}
            if (Test-Path "$DownloadPath\$DriverCab") {$OSDDriverStatus = 'Packaged'}
            if (Test-Path "$PackagePath\$DriverCab") {$OSDDriverStatus = 'Published'}
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
                DriverDownload      = $DriverDownload
                DriverZipFileName           = $DriverZipFileName
                DriverCab           = $DriverCab
            }
            New-Object -TypeName PSObject -Property $ObjectProperties
        }
    }
    Write-Host "Exporting $env:Temp\OSDDrivers $DriverGroup.xml" -ForegroundColor Cyan
    $DriverDownloads | Export-Clixml "$env:Temp\OSDDrivers $DriverGroup.xml" -Force
    $DriverDownloads = $DriverDownloads | Sort-Object -Property LastUpdated -Descending | Select-Object DriverGroup,DriverClass,OSDDriverStatus,LastUpdated,DriverName,DriverVersion,OSArch,OSVersionMin,OSVersionMax,Description,DriverDownload,DriverClassGUID,DriverPage,DriverZipFileName,DriverCab

    $DriverDownloads | Export-Clixml "$DownloadPath\OSDDrivers $DriverGroup.xml"
    if ($PackagePath) {
        $DriverDownloads | Export-Clixml "$PackagePath\OSDDrivers $DriverGroup.xml"
    }

    $DriverDownloads = $DriverDownloads | Out-GridView -PassThru -Title 'Select Driver Downloads to Package and press OK'
    #Return $DriverDownloads
    
    #===================================================================================================
    #   Download
    #===================================================================================================
    foreach ($SelectedDriverDownload in $DriverDownloads) {
        $OSDDriverStatus = $($SelectedDriverDownload.OSDDriverStatus)
        $DriverGroup = $($SelectedDriverDownload.DriverGroup)
        $DriverClass = $($SelectedDriverDownload.DriverClass)
        $DriverClassGUID = $($SelectedDriverDownload.DriverClassGUID)
        $DriverDownload = $($SelectedDriverDownload.DriverDownload)
        $DriverOSArch = $($SelectedDriverDownload.OSArch)
        $DriverOSVersionMin = $($SelectedDriverDownload.OSVersionMin)
        $DriverOSVersionMax = $($SelectedDriverDownload.OSVersionMax)

        $DriverCab = $($SelectedDriverDownload.DriverCab)
        $DriverZipFileName = $($SelectedDriverDownload.DriverZipFileName)
        $DriverDirectory = ($DriverCab).replace('.cab','')

        Write-Host "DriverDownload: $DriverDownload" -ForegroundColor Cyan
        Write-Host "DriverZipFileName: $DownloadPath\$DriverZipFileName" -ForegroundColor Gray

        if (Test-Path "$PackagePath\$DriverCab") {
            Write-Warning "$PackagePath\$DriverCab ... Exists!"
        } elseif (Test-Path "$DownloadPath\$DriverZipFileName") {
            Write-Warning "$DownloadPath\$DriverZipFileName ... Exists!"
        } else {
            Start-BitsTransfer -Source "$DriverDownload" -Destination "$DownloadPath\$DriverZipFileName"
        }
        if ($PackagePath) {
            #===================================================================================================
            #   Expand Zip
            #   Need to add logic to unzip if necessary
            #===================================================================================================
            if (-not(Test-Path "$PackagePath\$DriverCab")) {
                Write-Host "DriverDirectory: $DownloadPath\$DriverDirectory" -ForegroundColor Gray

                if (Test-Path "$DownloadPath\$DriverDirectory") {
                    Write-Warning "$DownloadPath\$DriverDirectory ... Removing!"
                    Remove-Item -Path "$DownloadPath\$DriverDirectory" -Recurse -Force | Out-Null
                }

                Write-Host "Expanding $DownloadPath\$DriverZipFileName ..." -ForegroundColor Gray
                Expand-Archive -Path "$DownloadPath\$DriverZipFileName" -DestinationPath "$DownloadPath\$DriverDirectory" -Force
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
            if ( -not (Test-Path "$DownloadPath\$DriverCab")) {
                Write-Verbose "Creating $DownloadPath\$DriverCab ..." -Verbose
                New-OSDDriverCAB -SourceDirectory "$DownloadPath\$DriverDirectory" -ShowOutput
            }
            #===================================================================================================
            #   Copy CAB
            #===================================================================================================
            if ( -not (Test-Path "$PackagePath\$DriverCab")) {
                Write-Verbose "Copying $DownloadPath\$DriverCab to $PackagePath\$DriverCab ..." -Verbose
                Copy-Item -Path "$DownloadPath\$DriverCab" -Destination "$PackagePath" -Force | Out-Null
            }
            #===================================================================================================
            #   OSDDriverTask
            #===================================================================================================
            Write-Host "Creating OSDDriverTask $DriverOSArch $DriverOSVersionMin $DriverOSVersionMax ..." -ForegroundColor Gray
            New-OSDDriverTask -DriverCab "$PackagePath\$DriverCab" -OSArch $DriverOSArch -OSVersionMin $DriverOSVersionMin -OSVersionMax $DriverOSVersionMax
            if (Test-Path "$OSDDriverPnp") {
                Copy-Item "$OSDDriverPnp" "$PackagePath" -Force
            }
        }
    }
}