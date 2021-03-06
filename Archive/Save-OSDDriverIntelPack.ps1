<#
.SYNOPSIS
Downloads IntelDisplay and IntelWireless Drivers

.DESCRIPTION
Downloads IntelDisplay and IntelWireless Drivers
Requires BITS for downloading the Downloads
Requires Internet access

.LINK
https://osddrivers.osdeploy.com/module/functions/save-osddriverintelpack
#>
function Save-OSDDriverIntelPack {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param (
        #Fully automatic Pack creation
        [Parameter(ParameterSetName = 'QuickPack', Mandatory = $true)]
        [ValidateSet('IntelPack 10.0 x64','IntelPack 10.0 x86','IntelPack 6.1 x64','IntelPack 6.1 x86')]
        [string]$QuickPack,

        #Appends the value to the Driver Pack Name
        [Parameter(ParameterSetName = 'Default')]
        [string]$AppendName = 'None',

        #Driver Pack supported Operating System Architecture
        [Parameter(ParameterSetName = 'Default')]
        [ValidateSet ('x64','x86')]
        [string]$OsArch,

        #Driver Pack supported Operating System Version
        [Parameter(ParameterSetName = 'Default')]
        [ValidateSet ('10.0','6.3','6.1')]
        [string]$OsVersion,

        #Creates a CAB file from the downloaded Intel Driver
        [Parameter(ParameterSetName = 'Default')]
        [switch]$Pack,

        #Skips GridView for Automation
        [Parameter(ParameterSetName = 'Default')]
        [switch]$SkipGridView,

        #Driver SubGroup
        [Parameter(ParameterSetName='Default')]
        [ValidateSet('*','IntelDisplay','IntelWireless')]
        [string]$SubGroup = '*'
    )

    Begin {
        #===================================================================================================
        #   Get-OSDDrivers
        #===================================================================================================
        Get-OSDDrivers -CreatePaths -HideDetails
        #===================================================================================================
        #   ParameterSetName
        #===================================================================================================
        if ($PSCmdlet.ParameterSetName -eq 'QuickPack') {
            $CustomName = $QuickPack
            $Pack = $true
            $SkipGridView = $true
            $SubGroup = '*'
            if ($QuickPack -eq 'IntelPack 10.0 x64') {
                $OsArch = 'x64'
                $OsVersion = '10.0'
            }
            if ($QuickPack -eq 'IntelPack 10.0 x86') {
                $OsArch = 'x86'
                $OsVersion = '10.0'
            }
            if ($QuickPack -eq 'IntelPack 6.1 x64') {
                $OsArch = 'x64'
                $OsVersion = '6.1'
            }
            if ($QuickPack -eq 'IntelPack 6.1 x86') {
                $OsArch = 'x86'
                $OsVersion = '6.1'
            }
        } else {
            if ($AppendName -eq 'None') {
                $CustomName = "IntelPack"
            } else {
                $CustomName = "IntelPack $AppendName"
            }
        }
        #===================================================================================================
        #   Get-OSDGather -Property IsAdmin
        #===================================================================================================
        if ($Pack -eq $true) {
            if ((Get-OSDGather -Property IsAdmin) -eq $false) {
                Write-Warning 'OSDDrivers: This function needs to be run as Administrator'
                Write-Warning 'OSDDrivers: This is to generate PNP information'
                Write-Warning "OSDDrivers: Pack creation will be disabled"
                $Pack = $false
            }
        }
        #===================================================================================================
        #   Display Paths
        #===================================================================================================
        Write-Verbose "Home: $GetOSDDriversHome" -Verbose
        Write-Verbose "Download: $SetOSDDriversPathDownload" -Verbose
        Write-Verbose "Expand: $SetOSDDriversPathExpand" -Verbose
        Write-Verbose "Packages: $SetOSDDriversPathPackages" -Verbose
        #===================================================================================================
        #   Publish Paths
        #===================================================================================================
        Publish-OSDDriverScripts -PublishPath $SetOSDDriversPathPackages
        $PackagePath = Get-PathOSDD -Path (Join-Path $SetOSDDriversPathPackages "$CustomName")
        Write-Verbose "Package Path: $PackagePath" -Verbose
        Publish-OSDDriverScripts -PublishPath $PackagePath
        #===================================================================================================
    }

    Process {
        Write-Verbose '========================================================================================' -Verbose
        Write-Verbose $MyInvocation.MyCommand.Name -Verbose
        #===================================================================================================
        #   Get-OSDDriver
        #===================================================================================================
        $OSDDrivers = @()
        if ($InputObject) {
            $SkipGridView = $true
            $OSDDrivers = $InputObject
        } else {
            if ($SubGroup -eq '*') {
                $OSDDrivers += Get-OSDDriver IntelDisplay
                $OSDDrivers += Get-OSDDriver IntelWireless
            } else {
                $OSDDrivers = Get-OSDDriver $SubGroup
            }
        }
        #===================================================================================================
        #   Set-OSDDriver
        #===================================================================================================
        foreach ($item in $OSDDrivers) {
            $DriverName = $item.DriverName
            $OSDCabFile = "$($DriverName).cab"
            $DownloadFile = $item.DownloadFile
            $OSDGroup = $item.OSDGroup
            $OSDType = $item.OSDType

            $DownloadedDriverGroup  = (Join-Path $global:SetOSDDriversPathDownload $OSDGroup)

            $DownloadedDriverPath = (Join-Path $SetOSDDriversPathDownload (Join-Path $OSDGroup $DownloadFile))
            if (Test-Path "$DownloadedDriverPath") {$item.OSDStatus = 'Downloaded'}

            $ExpandedDriverPath = (Join-Path $SetOSDDriversPathExpand (Join-Path $OSDGroup $DriverName))
            if (Test-Path "$ExpandedDriverPath") {$item.OSDStatus = 'Expanded'}

            $PackagedDriverPath = (Join-Path $PackagePath (Join-Path $OSDGroup $OSDCabFile))
            if (Test-Path "$PackagedDriverPath") {$item.OSDStatus = 'Packaged'}
        }
        #===================================================================================================
        #   Filters
        #===================================================================================================
        if ($OsArch) {$OSDDrivers = $OSDDrivers | Where-Object {$_.OsArch -match "$OsArch"}}
        if ($OsVersion) {$OSDDrivers = $OSDDrivers | Where-Object {$_.OsVersion -match "$OsVersion"}}
        #===================================================================================================
        #   GridView
        #===================================================================================================
        $OSDDrivers = $OSDDrivers | Sort-Object LastUpdate -Descending
        if ($SkipGridView.IsPresent) {
            Write-Warning "OSDDrivers: Skipping Out-GridView Selection"
        } else {
            $OSDDrivers = $OSDDrivers | Out-GridView -PassThru -Title "Select Drivers to Download and press OK"
        }
        #===================================================================================================
        #   Download
        #===================================================================================================
        Write-Verbose "==================================================================================================="
        foreach ($OSDDriver in $OSDDrivers) {
            $OSDType = $OSDDriver.OSDType
            Write-Verbose "OSDType: $OSDType"

            $DriverInfo = $OSDDriver.DriverInfo
            Write-Verbose "DriverInfo: $DriverInfo"

            $DriverUrl = $OSDDriver.DriverUrl
            Write-Verbose "DriverUrl: $DriverUrl"

            $DriverName = $OSDDriver.DriverName
            Write-Verbose "DriverName: $DriverName"

            $DriverGrouping = $OSDDriver.DriverGrouping
            Write-Verbose "DriverGrouping: $DriverGrouping"

            $DownloadFile = $OSDDriver.DownloadFile
            Write-Verbose "DownloadFile: $DownloadFile"

            $OSDGroup = $OSDDriver.OSDGroup
            Write-Verbose "OSDGroup: $OSDGroup"

            $OSDCabFile = "$($DriverName).cab"
            Write-Verbose "OSDCabFile: $OSDCabFile"

            $DownloadedDriverPath = (Join-Path $SetOSDDriversPathDownload (Join-Path $OSDGroup $DownloadFile))
            Write-Verbose "DownloadedDriverPath: $DownloadedDriverPath"

            $ExpandedDriverPath = (Join-Path $SetOSDDriversPathExpand (Join-Path $OSDGroup $DriverName))
            Write-Verbose "ExpandedDriverPath: $ExpandedDriverPath"


            $PackagedDriverPath = (Join-Path $PackagePath (Join-Path $OSDGroup $OSDCabFile))
            Write-Verbose "PackagedDriverPath: $PackagedDriverPath" -Verbose

            Write-Host "$DriverName" -ForegroundColor Green
            #===================================================================================================
            #   Driver Download
            #===================================================================================================
            Write-Host "Driver Download: $DownloadedDriverPath " -ForegroundColor Gray -NoNewline

            $DownloadedDriverGroup = Get-PathOSDD -Path (Join-Path $SetOSDDriversPathDownload $OSDGroup)

            if (Test-Path "$DownloadedDriverPath") {
                Write-Host 'Complete!' -ForegroundColor Cyan
            } else {
                Write-Host "Downloading ..." -ForegroundColor Cyan
                Write-Host "$DriverUrl" -ForegroundColor Gray
                if ($OSDGroup -eq 'AmdPack') {
                    #Thanks @manelrodero
                    $AmdAsk = Invoke-WebRequest -Uri "$DriverInfo" -Method Get
                    $Headers = @{ Referer = "$DriverInfo" ; Cookie = $AmdAsk.BaseResponse.Cookies }
                    Invoke-WebRequest -Uri "$DriverUrl" -Method Get -Headers $Headers -OutFile "$DownloadedDriverPath"
                } else {
                    Start-BitsTransfer -Source $DriverUrl -Destination "$DownloadedDriverPath" -ErrorAction Stop
                }
            }
            #===================================================================================================
            #   AmdPack Manual Download
            #===================================================================================================
            if (-not (Test-Path "$DownloadedDriverPath")) {
                if ($OSDGroup -eq 'AmdPack') {
                    Write-Host ""
                    Write-Warning "AMD has blocked direct Driver downloads so use this workaround"
                    Write-Host "1) Open the following URL: " -NoNewline -ForegroundColor Cyan
                    Write-Host "$DriverInfo"
                    Write-Host "2) Find the Driver link to " -NoNewline -ForegroundColor Cyan
                    Write-Host "$DownloadFile"
                    Write-Host "3) Save the download as " -NoNewline -ForegroundColor Cyan
                    Write-Host "$DownloadedDriverPath"
                    Write-Host ""
                    Pause
                }
            }
            #===================================================================================================
            #   Validate Driver Download
            #===================================================================================================
            if (-not (Test-Path "$DownloadedDriverPath")) {
                Write-Warning "Driver Download: Could not download Driver to $DownloadedDriverPath ... Exiting"
                Break
            }
            #===================================================================================================
            #   Driver Expand
            #===================================================================================================
            Write-Host "Driver Expand: $ExpandedDriverPath " -ForegroundColor Gray -NoNewline
            if (Test-Path "$ExpandedDriverPath") {
                Write-Host 'Complete!' -ForegroundColor Cyan
            } else {
                Write-Host 'Expanding ...' -ForegroundColor Cyan
                if ($DownloadFile -match '.zip') {
                    Expand-Archive -Path "$DownloadedDriverPath" -DestinationPath "$ExpandedDriverPath" -Force -ErrorAction Stop
                } elseif ($DownloadFile -match '.cab') {
                    if (-not (Test-Path "$ExpandedDriverPath")) {
                        New-Item "$ExpandedDriverPath" -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    }
                    Expand -R "$DownloadedDriverPath" -F:* "$ExpandedDriverPath" | Out-Null
                } else {
					& "$env:ProgramFiles\7-Zip\7z.exe" x -o"$ExpandedDriverPath" "$DownloadedDriverPath" -r ;
				}
            }
            #===================================================================================================
            #   Verify Driver Expand
            #===================================================================================================
            if (-not (Test-Path "$ExpandedDriverPath")) {
                Write-Warning "Driver Expand: Could not expand Driver to $ExpandedDriverPath ... Exiting"
                Break
            }
            $OSDDriver.OSDStatus = 'Expanded'
            #===================================================================================================
            #   PACK
            #===================================================================================================
            if ($Pack -eq $true) {
                #===================================================================================================
                #   Save-PnpOSDIntelPack
                #===================================================================================================
                $OSDPnpClass = $OSDDriver.OSDPnpClass
                $OSDPnpFile = "$($DriverName).drvpnp"

                Write-Host "Save-PnpOSDIntelPack: Generating OSDDriverPNP (OSDPnpClass: $OSDPnpClass) ..." -ForegroundColor Gray
                Save-PnpOSDIntelPack -ExpandedDriverPath "$ExpandedDriverPath" $OSDPnpClass
                #===================================================================================================
                #   ExpandedDriverPath OSDDriver Objects
                #===================================================================================================
                $OSDDriver | Export-Clixml -Path "$ExpandedDriverPath\OSDDriver.clixml" -Force
                $OSDDriver | ConvertTo-Json | Out-File -FilePath "$ExpandedDriverPath\OSDDriver.drvpack" -Force
                #===================================================================================================
                #   Create Package
                #===================================================================================================
                $PackagedDriverGroup = Get-PathOSDD -Path (Join-Path $PackagePath $OSDGroup)
                Write-Verbose "Verify: $PackagedDriverPath"
                if (Test-Path "$PackagedDriverPath") {
                    #Write-Warning "Compress-OSDDriver: $PackagedDriverPath already exists"
                } else {
                    New-CabFileOSDDriver -ExpandedDriverPath $ExpandedDriverPath -PublishPath $PackagedDriverGroup
                }
                #===================================================================================================
                #   Verify Driver Package
                #===================================================================================================
                if (-not (Test-Path "$PackagedDriverPath")) {
                    Write-Warning "Driver Expand: Could not package Driver to $PackagedDriverPath ... Exiting"
                    Continue
                }
                $OSDDriver.OSDStatus = 'Package'
                #===================================================================================================
                #   Export Results
                #===================================================================================================
                $OSDDriver | Export-Clixml -Path "$ExpandedDriverPath\OSDDriver.clixml" -Force
                $OSDDriver | ConvertTo-Json | Out-File -FilePath "$ExpandedDriverPath\OSDDriver.drvpack" -Force
                $OSDDriver | ConvertTo-Json | Out-File -FilePath "$PackagedDriverGroup\$($DriverName).drvpack" -Force
                #===================================================================================================
                #   Export Files
                #===================================================================================================
                #Write-Verbose "Verify: $ExpandedDriverPath\OSDDriver.drvpnp"
                if (Test-Path "$ExpandedDriverPath\OSDDriver.drvpnp") {
                    Write-Verbose "Copy-Item: $ExpandedDriverPath\OSDDriver.drvpnp to $PackagedDriverGroup\$OSDPnpFile"
                    Copy-Item -Path "$ExpandedDriverPath\OSDDriver.drvpnp" -Destination "$PackagedDriverGroup\$OSDPnpFile" -Force | Out-Null
                }
                $OSDDriver | Export-Clixml -Path "$ExpandedDriverPath\OSDDriver.clixml" -Force
                $OSDDriver | ConvertTo-Json | Out-File -FilePath "$ExpandedDriverPath\OSDDriver.drvpack" -Force
                $OSDDriver | ConvertTo-Json | Out-File -FilePath "$PackagedDriverGroup\$($DriverName).drvpack" -Force
                #===================================================================================================
                #   Publish-OSDDriverScripts
                #===================================================================================================
                #Publish-OSDDriverScripts -PublishPath $PackagedDriverGroup
            }
        }
    }

    End {
        #===================================================================================================
        #   Publish-OSDDriverScripts
        #===================================================================================================
        Write-Host "Complete!" -ForegroundColor Green
        #===================================================================================================
    }
}