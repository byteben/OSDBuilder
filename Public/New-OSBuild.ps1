<#
.SYNOPSIS
Creates a new OSBuild from an OSBuild Task

.DESCRIPTION
Creates a new OSBuild from an OSBuild Task created with New-OSBuildTask

.LINK
https://osdbuilder.osdeploy.com/module/functions/new-osbuild

.NOTES
19.10.28 MMSJazz Ready
19.10.14 Added HideCleanupProgress
19.10.13 Added SelectUpdates SkipUpdates
#>
function New-OSBuild {
    [CmdletBinding(DefaultParameterSetName='Basic')]
    Param (
        #Specify the Name of the OSMedia to use with New-OSBuild
        [Parameter(ParameterSetName='Taskless', ValueFromPipelineByPropertyName=$True)]
        [string[]]$Name,

        #Name of the Task to execute
        [Parameter(ParameterSetName='Basic')]
        [string]$ByTaskName = $global:SetOSDBuilder.NewOSBuildByTaskName,

        #Creates an ISO of the Updated Media
        #oscdimg.exe from Windows ADK is required
        [Alias('ISO','OSDISO')]
        [switch]$CreateISO = $global:SetOSDBuilder.NewOSBuildCreateISO,
        
        #Use the OSMedia specified in the Task
        [Parameter(ParameterSetName='Basic')]
        [switch]$DontUseNewestMedia = $global:SetOSDBuilder.NewOSBuildDontUseNewestMedia,

        #Automatically download the required updates if they are not present in the Content\OSDUpdate directory
        [Alias('GetDown')]
        [switch]$Download = $global:SetOSDBuilder.NewOSBuildDownload,

        #Executes Update-OSMedia
        #Without this parameter, Update-OSMedia is in Sandbox Mode where changes will not be made
        [Alias('Force')]
        [switch]$Execute = $global:SetOSDBuilder.NewOSBuildExecute,

        #Enables NetFX without creating a Task
        [Parameter(ParameterSetName='Taskless')]
        [switch]$EnableNetFX = $global:SetOSDBuilder.NewOSBuildEnableNetFX,

        #Hides the Dism Cleanup-Image Progress
        [switch]$HideCleanupProgress = $global:SetOSDBuilder.NewOSBuildHideCleanupProgress,

        #Pauses the function the Install.wim is dismounted
        #Useful for Testing
        [Alias('PauseOS','PauseDismount')]
        [switch]$PauseDismountOS = $global:SetOSDBuilder.NewOSBuildPauseDismountOS,

        #Pauses the function before WinPE is dismounted
        #Useful for Testing
        [Alias('PausePE')]
        [switch]$PauseDismountPE = $global:SetOSDBuilder.NewOSBuildPauseDismountPE,

        #Add a ContentPack without creating a Task
        [Parameter(ParameterSetName='Taskless')]
        [switch]$SelectContentPacks = $global:SetOSDBuilder.NewOSBuildSelectContentPacks,

        #Allows you to select Updates to apply in GridView
        #Useful for Testing
        [switch]$SelectUpdates = $global:SetOSDBuilder.NewOSBuildSelectUpdates,

        #By default only the OSMedia that needs to be updated is displayed
        #This parameter includes the hidden OSMedia
        [Alias('ShowAllOSMedia','Superseded')]
        [switch]$ShowHiddenOSMedia = $global:SetOSDBuilder.NewOSBuildShowHiddenOSMedia,

        #Skips DISM /Cleanup-Image /StartComponentCleanup /ResetBase
        #Images created for Citrix PVS require this parameter
        #Useful for testing to reduce the time
        [Alias('SkipCleanup','Citrix','PVS')]
        [switch]$SkipComponentCleanup = $global:SetOSDBuilder.NewOSBuildSkipComponentCleanup,

        #Create a new OSBuild without applying ContentPacks
        [switch]$SkipContentPacks = $global:SetOSDBuilder.NewOSBuildSkipContentPacks,

        #Create a new OSBuild without applying Templates
        [switch]$SkipTemplates = $global:SetOSDBuilder.NewOSBuildSkipTemplates,
        
        #Allows you to skip all Updates from being applied
        #Useful for Testing
        [switch]$SkipUpdates = $global:SetOSDBuilder.NewOSBuildSkipUpdates,

        #Skip applying updates in WinPE
        #Useful for Testing
        [switch]$SkipUpdatesPE = $global:SetOSDBuilder.NewOSBuildSkipUpdatesPE,

        #Create a new OSBuild from OSMedia without a Task
        [Parameter(ParameterSetName='Taskless', Mandatory=$True)]
        [switch]$SkipTask = $global:SetOSDBuilder.NewOSBuildSkipTask
    )

    Begin {
        #===================================================================================================
        #   Get-OSDBuilder
        #===================================================================================================
        Get-OSDBuilder -CreatePaths -HideDetails
        #===================================================================================================
        #   Get-OSDUpdates
        #===================================================================================================
        $AllOSDUpdates = @()
        $AllOSDUpdates = Get-OSDUpdates
        #===================================================================================================
        #   Get-OSDGather -Property IsAdmin
        #===================================================================================================
        if ((Get-OSDGather -Property IsAdmin) -eq $false) {
            Write-Warning 'OSDBuilder: This function needs to be run as Administrator'
            Pause
            Break
        }
    }

    Process {
        Write-Host '========================================================================================' -ForegroundColor DarkGray
        Write-Host -ForegroundColor Green "$($MyInvocation.MyCommand.Name) PROCESS"
        Write-Verbose "MyInvocation.MyCommand.Name: $($MyInvocation.MyCommand.Name)"
        Write-Verbose "PSCmdlet.ParameterSetName: $($PSCmdlet.ParameterSetName)"
        #===================================================================================================
        #   OSBuild
        #===================================================================================================
        if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild') {
            if ($PSCmdlet.ParameterSetName -eq 'Taskless') {
                if ($Name) {
                    Write-Verbose "Parameter Name: $Name"
                    $BirdBox = foreach ($Task in $Name) {
                        $ObjectProperties = @{
                            Name = $Task
                        }
                        New-Object -TypeName PSObject -Property $ObjectProperties
                    }
                } else {
                    $BirdBox = @()
                    if ($ShowHiddenOSMedia.IsPresent) {
                        $BirdBox = Get-OSMedia
                    } else {
                        $BirdBox = Get-OSMedia -Revision OK -OSMajorVersion 10
                    }
                    $BirdBox = $BirdBox | Out-GridView -PassThru -Title "Select one or more OSMedia to Build (Cancel to Exit) and press OK"
                }
                if ($null -eq $BirdBox) {
                    Write-Warning "Could not find a matching OSMedia . . . Exiting!"
                    Return
                }
            } else {
                if ($ByTaskName) {
                    $BirdBox = @()
                    $BirdBox = Get-OSBuildTask | Where-Object {$_.TaskName -eq "$ByTaskName"}
                } else {
                    $BirdBox = @()
                    $BirdBox = Get-OSBuildTask | Out-GridView -PassThru -Title "OSBuild Tasks: Select one or more Tasks to execute and press OK (Cancel to Exit)"
                }

                if ($null -eq $BirdBox) {
                    Write-Warning "OSBuild Task was not selected or found . . . Exiting!"
                    Return
                }
            }
        }
        #===================================================================================================
        #   Update-OSMedia
        #===================================================================================================
        if ($MyInvocation.MyCommand.Name -eq 'Update-OSMedia') {
            if ($Name) {
                $BirdBox = foreach ($Item in $Name) {
                    Write-Verbose '========== Checking $Item'
                    $ObjectProperties = @{
                        Name = $Item
                    }
                    New-Object -TypeName PSObject -Property $ObjectProperties
                }
            } else {
                $BirdBox = @()
                if ($ShowHiddenOSMedia.IsPresent) {
                    $BirdBox = Get-OSMedia
                } else {
                    $BirdBox = Get-OSMedia -Revision OK -Updates Update
                }
                if ($UpdateNeeded.IsPresent) {
                    if ($BirdBox | Where-Object {$_.MajorVersion -eq 6}) {
                        Write-Warning "UpdateNeeded does not support Legacy Operating Systems"
                        Write-Warning "Legacy Operating Systems have been removed from the results"
                        $BirdBox = $BirdBox | Where-Object {$_.MajorVersion -eq 10}
                    }
                    $BirdBox = $BirdBox | Where-Object {($_.Servicing -eq '') -or ($_.Cumulative -eq '') -or ($_.Adobe -eq '')}
                }
                $BirdBox = $BirdBox | Where-Object {($_.MajorVersion -eq 10) -or ($_.InstallationType -like "*Client*" -and $_.Version -like "6.1.7601*") -or ($_.InstallationType -like "*Server*" -and $_.Version -like "6.3*")}
                $BirdBox = $BirdBox | Out-GridView -PassThru -Title "Select one or more OSMedia to Update (Cancel to Exit) and press OK"
            }
        }

        foreach ($Bird in $BirdBox) {
            #===================================================================================================
            #   New-OSBuild
            #===================================================================================================
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild') {
                if ($PSCmdlet.ParameterSetName -eq 'Taskless') {
                    #$Task = Get-OSMedia -Revision OK | Where-Object {$_.Name -eq $Bird.Name}
                    $Task = Get-OSMedia | Where-Object {$_.Name -eq $Bird.Name} | Sort-Object ModifiedTime | Select-Object -Last 1

                    $TaskType = 'OSBuild'
                    $TaskName = 'Taskless'
                } else {
                    (Get-Content "$($Bird.FullName)").replace('WinPEAddDaRT', 'WinPEDaRT') | Set-Content "$($Bird.FullName)"
                    $Task = Get-Content "$($Bird.FullName)" | ConvertFrom-Json

                    $TaskType = $Task.TaskType
                    $TaskName = $Task.TaskName
                }
                $TaskVersion = $Task.TaskVersion
                $CustomName = $Task.CustomName
                if ((Get-IsContentPacksEnabled) -and (!($SkipContentPacks.IsPresent))) {
                    if ($null -eq $Task.ContentPacks) {
                        $ContentPacks = @('_Global')
                    } else {
                        $ContentPacks = @('_Global')
                        $ContentPacks = ($ContentPacks += $Task.ContentPacks)
                    }
                }
                $TaskOSMFamily = $Task.OSMFamily
                $TaskOSMGuid = $Task.OSMGuid
                $OSMediaName = $Task.Name
                if (Test-Path "$SetOSDBuilderPathOSMedia\$OSMediaName") {$OSMediaPath = "$SetOSDBuilderPathOSMedia\$OSMediaName"}
                if (Test-Path "$SetOSDBuilderPathOSImport\$OSMediaName") {$OSMediaPath = "$SetOSDBuilderPathOSImport\$OSMediaName"}
                $EnableNetFX3 = $Task.EnableNetFX3
                $StartLayoutXML = $Task.StartLayoutXML
                $UnattendXML = $Task.UnattendXML
                $WinPEAutoExtraFiles = $Task.WinPEAutoExtraFiles
                $WinPEDaRT = $Task.WinPEDart
                $ExtraFiles = $Task.ExtraFiles
                $Scripts = $Task.Scripts
                $Drivers = $Task.Drivers

                $Packages = $Task.AddWindowsPackage
                $RemovePackage = $Task.RemoveWindowsPackage
                $FeaturesOnDemand = $Task.AddFeatureOnDemand
                $EnableFeature = $Task.EnableWindowsOptionalFeature
                $DisableFeature = $Task.DisableWindowsOptionalFeature
                $RemoveAppx = $Task.RemoveAppxProvisionedPackage
                $RemoveCapability = $Task.RemoveWindowsCapability

                $WinPEDrivers = $Task.WinPEDrivers
                $WinPEScriptsPE = $Task.WinPEScriptsPE
                $WinPEScriptsRE = $Task.WinPEScriptsRE
                $WinPEScriptsSE = $Task.WinPEScriptsSE
                $WinPEExtraFilesPE = $Task.WinPEExtraFilesPE
                $WinPEExtraFilesRE = $Task.WinPEExtraFilesRE
                $WinPEExtraFilesSE = $Task.WinPEExtraFilesSE
                $WinPEADKPE = $Task.WinPEADKPE
                $WinPEADKRE = $Task.WinPEADKRE
                $WinPEADKSE = $Task.WinPEADKSE
                
                $SetAllIntl = $Task.LangSetAllIntl
                $SetInputLocale = $Task.LangSetInputLocale
                $SetSKUIntlDefaults = $Task.LangSetSKUIntlDefaults
                $SetSetupUILang = $Task.LangSetSetupUILang
                $SetSysLocale = $Task.LangSetSysLocale
                $SetUILang = $Task.LangSetUILang
                $SetUILangFallback = $Task.LangSetUILangFallback
                $SetUserLocale = $Task.LangSetUserLocale
                $LanguageFeatures = $Task.LanguageFeature
                $LanguagePacks = $Task.LanguagePack
                $LanguageInterfacePacks = $Task.LanguageInterfacePack
                $LocalExperiencePacks = $Task.LocalExperiencePacks
                $LanguageCopySources = $Task.LanguageCopySources
                
                if (!($TaskName -eq 'Taskless')) {Show-TaskInfo}
            }
            #===================================================================================================
            #   OSBuild
            Write-Verbose '19.1.1 Validate Proper TaskVersion'
            #===================================================================================================
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (!($TaskName -eq 'Taskless'))) {
                if ([System.Version]$TaskVersion -lt [System.Version]"19.1.4.0") {
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    Write-Warning "OSDBuilder Tasks need to be version 19.1.4.0 or newer"
                    Write-Warning "Recreate this Task using New-OSBuildTask or Repair-OSBuildTask"
                    Return
                }
            }
            #===================================================================================================
            #   OSBuild
            Write-Verbose '19.3.21 Select Latest OSMedia'
            #===================================================================================================
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (!($DontUseNewestMedia))) {
                if ($TaskName -eq 'Taskless') {
                    $TaskOSMedia = Get-OSMedia | Where-Object {$_.Name -eq $OSMediaName}
                    Write-Verbose "$TaskOSMedia | ft"
                } else {
                    $TaskOSMedia = Get-OSMedia | Where-Object {$_.OSMGuid -eq $TaskOSMGuid}
                }

                $OSMediaName = $TaskOSMedia.Name
                $OSMediaPath = $TaskOSMedia.FullName
                if ($TaskOSMedia) {
                    $OSMediaName = $TaskOSMedia.Name
                    $OSMediaPath = $TaskOSMedia.FullName
                    #Write-Host '========================================================================================' -ForegroundColor DarkGray
                    #Write-Host "Task Source OSMedia" -ForegroundColor Green
                    #Write-Host "-OSMedia Name:                  $OSMediaName"
                    #Write-Host "-OSMedia Path:                  $OSMediaPath"
                    #Write-Host "-OSMedia Family:                $TaskOSMFamily"
                    #Write-Host "-OSMedia Guid:                  $TaskOSMGuid"
                }
                $LatestOSMedia = Get-OSMedia -Revision OK | Where-Object {$_.OSMFamily -eq $TaskOSMFamily}
                if ($LatestOSMedia) {
                    $OSMediaName = $LatestOSMedia.Name
                    $OSMediaPath = $LatestOSMedia.FullName
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    Write-Host "Latest Source OSMedia" -ForegroundColor Green
                    Write-Host "-OSMedia Name:              $OSMediaName"
                    Write-Host "-OSMedia Path:              $OSMediaPath"
                    Write-Host "-OSMedia Family:            $($LatestOSMedia.OSMFamily)"
                    Write-Host "-OSMedia Guid:              $($LatestOSMedia.OSMGuid)"
                } else {
                    Write-Warning "Unable to find a matching OSMFamily $TaskOSMFamily"
                    Return
                }

<#                 if ($null -eq $OSMediaPath) {
                    Write-Warning "Unable to find a matching OSMedia"
                    Return
                } #>
            }
            
            #===================================================================================================
            #   OSBuild
            Write-Verbose '19.1.22 Templates'
            #===================================================================================================
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (Test-Path $SetOSDBuilderPathTemplates) -and (!($SkipTemplates.IsPresent))) {
                Get-ChildItem -Path $SetOSDBuilderPathTemplates *.json | foreach {(Get-Content "$($_.FullName)").replace('WinPEAddDaRT', 'WinPEDaRT') | Set-Content "$($_.FullName)"}
                $Templates = @()
                $Templates = Get-ChildItem -Path $SetOSDBuilderPathTemplates OSBuild*.json | ForEach-Object {Get-Content -Path $_.FullName | ConvertFrom-Json | Select-Object -Property *}

                if ($Templates){
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    Write-Host "OSBuild Templates" -ForegroundColor Green
                }

                foreach ($Task in $Templates) {
                    if ($Task.TaskName -like "*Global*") {
                        Write-Host "Global: $($Task.TaskName)"
                    } elseif ($Task.OSMFamily -eq $TaskOSMFamily) {
                        Write-Host "OSMedia Family: $($Task.TaskName)"
                    } else {
                        Write-Host "Skipping: $($Task.TaskName)" -ForegroundColor DarkGray
                        Continue
                    }
                    $ContentPacks += @($Task.ContentPacks | Where-Object {$_})

                    if (!($Task.EnableNetFX3 -eq $False)) {$EnableNetFX3 = $Task.EnableNetFX3}
                    if ($Task.StartLayoutXML) {$StartLayoutXML = $Task.StartLayoutXML}
                    if ($Task.UnattendXML) {$UnattendXML = $Task.UnattendXML}
                    if (!($Task.WinPEAutoExtraFiles -eq $False)) {$WinPEAutoExtraFiles = $Task.WinPEAutoExtraFiles}
                    if ($Task.WinPEDaRT) {$WinPEDaRT = $Task.WinPEDaRT}
                    
                    $ExtraFiles += @($Task.ExtraFiles | Where-Object {$_})
                    $Scripts += @($Task.Scripts | Where-Object {$_})
                    $Drivers += @($Task.Drivers | Where-Object {$_})
    
                    $Packages += @($Task.AddWindowsPackage | Where-Object {$_})
                    $RemovePackage += @($Task.RemoveWindowsPackage | Where-Object {$_})
                    $FeaturesOnDemand += @($Task.AddFeatureOnDemand | Where-Object {$_})
                    $EnableFeature += @($Task.EnableWindowsOptionalFeature | Where-Object {$_})
                    $DisableFeature += @($Task.DisableWindowsOptionalFeature | Where-Object {$_})
                    $RemoveAppx += @($Task.RemoveAppxProvisionedPackage | Where-Object {$_})
                    $RemoveCapability += @($Task.RemoveWindowsCapability | Where-Object {$_})
    
                    $WinPEDrivers += @($Task.WinPEDrivers | Where-Object {$_})
                    $WinPEScriptsPE += @($Task.WinPEScriptsPE | Where-Object {$_})
                    $WinPEScriptsRE += @($Task.WinPEScriptsRE | Where-Object {$_})
                    $WinPEScriptsSE += @($Task.WinPEScriptsSE | Where-Object {$_})
                    $WinPEExtraFilesPE += @($Task.WinPEExtraFilesPE | Where-Object {$_})
                    $WinPEExtraFilesRE += @($Task.WinPEExtraFilesRE | Where-Object {$_})
                    $WinPEExtraFilesSE += @($Task.WinPEExtraFilesSE | Where-Object {$_})
                    $WinPEADKPE += @($Task.WinPEADKPE | Where-Object {$_})
                    $WinPEADKRE += @($Task.WinPEADKRE | Where-Object {$_})
                    $WinPEADKSE += @($Task.WinPEADKSE | Where-Object {$_})
                    
                    if ($Task.SetAllIntl) {$SetAllIntl = $Task.SetAllIntl}
                    if ($Task.LangSetInputLocale) {$SetInputLocale = $Task.LangSetInputLocale}
                    if ($Task.LangSetSKUIntlDefaults) {$SetSKUIntlDefaults = $Task.LangSetSKUIntlDefaults}
                    if ($Task.LangSetSetupUILang) {$SetSetupUILang = $Task.LangSetSetupUILang}
                    if ($Task.LangSetSysLocale) {$SetSysLocale = $Task.LangSetSysLocale}
                    if ($Task.LangSetUILang) {$SetUILang = $Task.LangSetUILang}
                    if ($Task.LangSetUILangFallback) {$SetUILangFallback = $Task.LangSetUILangFallback}
                    if ($Task.LangSetUserLocale) {$SetUserLocale = $Task.LangSetUserLocale}
                    $LanguageFeatures += @($Task.LanguageFeature | Where-Object {$_})
                    $LanguagePacks += @($Task.LanguagePack | Where-Object {$_})
                    $LanguageInterfacePacks += @($Task.LanguageInterfacePack | Where-Object {$_})
                    $LocalExperiencePacks += @($Task.LocalExperiencePacks | Where-Object {$_})
                    $LanguageCopySources += @($Task.LanguageCopySources | Where-Object {$_})
                }
            }
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild') {
                if ($EnableNetFX.IsPresent) {$EnableNetFX3 = $true}
                if ((Get-IsContentPacksEnabled) -and ($SelectContentPacks.IsPresent)) {
                    $ContentPacks = (Get-TaskContentPacks -Select).Name
                }
                Show-TaskInfo
            }
            #===================================================================================================
            Write-Verbose '19.1.1 Set Proper Paths'
            #===================================================================================================
            if ($MyInvocation.MyCommand.Name -eq 'Update-OSMedia') {
                if (Test-Path "$SetOSDBuilderPathOSImport\$($Bird.Name)") {$OSMediaPath = "$SetOSDBuilderPathOSImport\$($Bird.Name)"}
                if (Test-Path "$SetOSDBuilderPathOSMedia\$($Bird.Name)") {$OSMediaPath = "$SetOSDBuilderPathOSMedia\$($Bird.Name)"}
            }
            $OSImagePath = "$OSMediaPath\OS\sources\install.wim"

            if (!(Test-Path "$OSMediaPath\WindowsImage.txt")) {
                Write-Host '========================================================================================' -ForegroundColor DarkGray
                if ($null -eq $OSMediaPath) {
                    Write-Warning "Unable to find an OSMedia to use"
                } else {
                    Write-Warning "$OSMediaPath is not a valid OSMedia Directory"
                }
                Return
            }

            if (!(Test-Path "$OSImagePath")) {
                Write-Host '========================================================================================' -ForegroundColor DarkGray
                Write-Warning "$OSImagePath is not a valid Windows Image"
                Return
            }

            #===================================================================================================
            Write-Verbose '19.1.1 Get Windows Image Information'
            #===================================================================================================
            $OSImageIndex = 1
            $WindowsImage = Get-WindowsImage -ImagePath "$OSImagePath" -Index $OSImageIndex | Select-Object -Property *

            $OSImageName = $($WindowsImage.ImageName)
            $OSImageName = $OSImageName -replace '\(', ''
            $OSImageName = $OSImageName -replace '\)', ''

            $OSImageDescription = $($WindowsImage.ImageDescription)

            $OSArchitecture = $($WindowsImage.Architecture)
            if ($OSArchitecture -eq '0') {$OSArchitecture = 'x86'}
            if ($OSArchitecture -eq '6') {$OSArchitecture = 'ia64'}
            if ($OSArchitecture -eq '9') {$OSArchitecture = 'x64'}
            if ($OSArchitecture -eq '12') {$OSArchitecture = 'x64 ARM'}

            $OSEditionID =          $($WindowsImage.EditionId)
            $OSInstallationType =   $($WindowsImage.InstallationType)
            $OSLanguages =          $($WindowsImage.Languages)
            $OSVersion =            $($WindowsImage.Version)
            $OSMajorVersion =       $($WindowsImage.MajorVersion)
            $OSMinorVersion =       $($WindowsImage.MinorVersion)
            $OSBuild =              $($WindowsImage.Build)
            $OSSPBuild =            $($WindowsImage.SPBuild)
            $OSSPLevel =            $($WindowsImage.SPLevel)
            $OSImageBootable =      $($WindowsImage.ImageBootable)
            $OSWIMBoot =            $($WindowsImage.WIMBoot)
            $OSCreatedTime =        $($WindowsImage.CreatedTime)
            $OSModifiedTime =       $($WindowsImage.ModifiedTime)

            Show-MediaImageInfoOS
            #===================================================================================================
            Write-Verbose '19.1.1 Validate Registry CurrentVersion.xml'
            #===================================================================================================
            $RegValueCurrentBuild = $null
            if (Test-Path "$OSMediaPath\info\xml\CurrentVersion.xml") {
                $RegKeyCurrentVersion = Import-Clixml -Path "$OSMediaPath\info\xml\CurrentVersion.xml"
                $ReleaseId = $($RegKeyCurrentVersion.ReleaseId)
                $RegValueCurrentBuild = $($RegKeyCurrentVersion.CurrentBuild)
                if ($ReleaseId -gt 1909) {
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    Write-Warning "OSDBuilder does not currently support this version of Windows ... Check for an updated version"
                }
            }
            #===================================================================================================
            Write-Verbose '19.1.1 Set ReleaseId'
            #===================================================================================================
            if ($null -ne $RegValueCurrentBuild) {$OSBuild = $RegValueCurrentBuild}
            if ($null -eq $ReleaseId) {
                if ($OSBuild -eq 7600) {$ReleaseId = 7600}
                if ($OSBuild -eq 7601) {$ReleaseId = 7601}
                if ($OSBuild -eq 9600) {$ReleaseId = 9600}
                if ($OSBuild -eq 10240) {$ReleaseId = 1507}
                if ($OSBuild -eq 14393) {$ReleaseId = 1607}
                if ($OSBuild -eq 15063) {$ReleaseId = 1703}
                if ($OSBuild -eq 16299) {$ReleaseId = 1709}
                if ($OSBuild -eq 17134) {$ReleaseId = 1803}
                if ($OSBuild -eq 17763) {$ReleaseId = 1809}
                #if ($OSBuild -eq 18362) {$ReleaseId = 1903}
                #if ($OSBuild -eq 18363) {$ReleaseId = 1909}
                #if ($OSBuild -eq 18990) {$ReleaseId = 2001}
            }
            #===================================================================================================
            #   Operating System
            #===================================================================================================
            $UpdateOS = ''
            if ($OSMajorVersion -eq 10) {
                if ($OSInstallationType -notlike "*Server*") {$UpdateOS = 'Windows 10'}
                elseif ($OSBuild -ge 17763) {$UpdateOS = 'Windows Server 2019'}
                else {$UpdateOS = 'Windows Server 2016'}
            } elseif ($OSMajorVersion -eq 6) {
                if ($OSInstallationType -like "*Server*") {
                    if ($OSVersion -like "6.3*") {
                        $UpdateOS = 'Windows Server 2012 R2'
                    }
                    elseif ($OSVersion -like "6.2*") {
                        $UpdateOS = 'Windows Server 2012'
                        Write-Warning "This Operating System is not supported"
                        Return
                    }
                    elseif ($OSVersion -like "6.1*") {
                        $UpdateOS = 'Windows Server 2008 R2'
                        Write-Warning "This Operating System is not supported"
                        Return
                    }
                    else {
                        Write-Warning "This Operating System is not supported"
                    }
                } else {
                    if ($OSVersion -like "6.3*") {
                        $UpdateOS = 'Windows 8.1'
                        Write-Warning "This Operating System is not supported"
                        Return
                    }
                    elseif ($OSVersion -like "6.2*") {
                        $UpdateOS = 'Windows 8'
                        Write-Warning "This Operating System is not supported"
                        Return
                    }
                    elseif ($OSVersion -like "6.1*") {
                        $UpdateOS = 'Windows 7'
                    }
                    else {
                        Write-Warning "This Operating System is not supported"
                    }
                }
            }
            #===================================================================================================
            Write-Verbose '19.1.1 WorkingName and WorkingPath'
            #===================================================================================================
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild') {
                $WorkingName = "build$((Get-Date).ToString('mmss'))"
                $WorkingPath = "$SetOSDBuilderPathOSBuilds\$WorkingName"
            } else {
                $WorkingName = "build$((Get-Date).ToString('mmss'))"
                $WorkingPath = "$SetOSDBuilderPathOSMedia\$WorkingName"
            }
            #===================================================================================================
            Write-Verbose '19.1.1 Remove Existing OSMedia'
            #===================================================================================================
            if (Test-Path $WorkingPath) {
                Write-Host '========================================================================================' -ForegroundColor DarkGray
                Write-Warning "$WorkingPath will be replaced!"
            }
            #===================================================================================================
            #   Template Content
            #===================================================================================================
            if (Get-IsTemplatesEnabled) {
                #===================================================================================================
                #   OSBuild
                #   Driver Templates
                #===================================================================================================
                if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (Test-Path $SetOSDBuilderPathTemplates) -and (!($SkipTemplates.IsPresent))) {
                    $DriverTemplates = Get-OSTemplateDrivers
                    if ($DriverTemplates) {
                        Write-Host '========================================================================================' -ForegroundColor DarkGray
                        Write-Host "OSBuild Template Driver Directories (Applied)" -ForegroundColor Green
                        foreach ($Item in $DriverTemplates) {Write-Host $Item.FullName -ForegroundColor Gray}
                    }
                }
                #===================================================================================================
                #   OSBuild
                #   ExtraFiles Templates
                #===================================================================================================
                if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (Test-Path $SetOSDBuilderPathTemplates) -and (!($SkipTemplates.IsPresent))) {
                    #Write-Host "OSBuild Template ExtraFiles Directories (Searched)" -ForegroundColor Green
                    $ExtraFilesTemplates = Get-OSTemplateExtraFiles
                    if ($ExtraFilesTemplates) {
                        Write-Host '========================================================================================' -ForegroundColor DarkGray
                        Write-Host "OSBuild Template ExtraFiles Files (Applied)" -ForegroundColor Green
                        foreach ($Item in $ExtraFilesTemplates) {Write-Host $Item.FullName -ForegroundColor Gray}
                    }
                }
                #===================================================================================================
                #   OSBuild
                #   Registry REG Templates
                #===================================================================================================
                if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (Test-Path $SetOSDBuilderPathTemplates) -and (!($SkipTemplates.IsPresent))) {
                    #Write-Host "OSBuild Template Registry REG Directories (Searched)" -ForegroundColor Green
                    $RegistryTemplatesReg = Get-OSTemplateRegistryReg
                    if ($RegistryTemplatesReg) {
                        Write-Host '========================================================================================' -ForegroundColor DarkGray
                        Write-Host "OSBuild Template Registry REG Files (Applied)" -ForegroundColor Green
                        foreach ($Item in $RegistryTemplatesReg) {Write-Host $Item.FullName -ForegroundColor Gray}
                    }
                }
                #===================================================================================================
                #   OSBuild
                #   Registry XML Templates
                #===================================================================================================
                if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (Test-Path $SetOSDBuilderPathTemplates) -and (!($SkipTemplates.IsPresent))) {
                    #Write-Host "OSBuild Template Registry XML Directories (Searched)" -ForegroundColor Green
                    $RegistryTemplatesXml = Get-OSTemplateRegistryXml
                    if ($RegistryTemplatesXml) {
                        Write-Host '========================================================================================' -ForegroundColor DarkGray
                        Write-Host "OSBuild Template Registry XML Files (Applied)" -ForegroundColor Green
                        foreach ($Item in $RegistryTemplatesXml) {Write-Host $Item.FullName -ForegroundColor Gray}
                    }
                }
                #===================================================================================================
                #   OSBuild
                #   Script Templates
                #===================================================================================================
                if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and (Test-Path $SetOSDBuilderPathTemplates) -and (!($SkipTemplates.IsPresent))) {
                    #Write-Host "OSBuild Template Script Directories (Searched)" -ForegroundColor Green
                    $ScriptTemplates = Get-OSTemplateScripts
                    if ($ScriptTemplates) {
                        Write-Host '========================================================================================' -ForegroundColor DarkGray
                        Write-Host "OSBuild Template Script Files (Applied)" -ForegroundColor Green
                        foreach ($Item in $ScriptTemplates) {Write-Host $Item.FullName -ForegroundColor Gray}
                    }
                }
            }
            #===================================================================================================
            #   Operating System Updates
            #===================================================================================================
            Write-Host '========================================================================================' -ForegroundColor DarkGray
            Write-Host "Operating System Updates" -ForegroundColor Green
            #===================================================================================================
            #   OSDUpdates
            #===================================================================================================
            $OSDUpdates = $AllOSDUpdates
            if ($SkipUpdates.IsPresent) {$OSDUpdates = @()}
            $OSDUpdates = $OSDUpdates | Where-Object {$_.UpdateArch -eq $OSArchitecture}
            $OSDUpdates = $OSDUpdates | Where-Object {$_.UpdateOS -eq $UpdateOS}
            $OSDUpdates = $OSDUpdates | Where-Object {($_.UpdateBuild -eq $ReleaseId) -or ($_.UpdateBuild -eq '')}
            if ($OSInstallationType -match 'Core'){$OSDUpdates = $OSDUpdates | Where-Object {$_.UpdateGroup -ne 'AdobeSU'}}
            if ($SelectUpdates.IsPresent) {$OSDUpdates = $OSDUpdates | Out-GridView -PassThru -Title 'Select Updates to Apply and press OK'}
            $MissingUpdate = $false
            #===================================================================================================
            #   OSDBuilder 10 Setup Updates
            #===================================================================================================
            $OSDUpdateSetupDU = @()
            $OSDUpdateSetupDU = $OSDUpdates | Where-Object {$_.UpdateGroup -eq 'SetupDU'}
            $OSDUpdateSetupDU = $OSDUpdateSetupDU | Sort-Object -Property CreationDate
            foreach ($Update in $OSDUpdateSetupDU) {
                if ($Update.OSDStatus -eq 'Downloaded') {
                    Write-Host "Ready       SetupDU         $($Update.Title)"
                } else {
                    if ($Download.IsPresent) {
                        Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                    } else {
                        Write-Host "Missing     SetupDU         $($Update.Title)" -ForegroundColor Yellow
                        $Execute = $false
                        $MissingUpdate = $true
                    }
                }
            }
            #===================================================================================================
            #   OSDBuilder 10 Component Updates
            #===================================================================================================
            $OSDUpdateComponentDU = @()
            $OSDUpdateComponentDU = $OSDUpdates | Where-Object {$_.UpdateGroup -like "ComponentDU*"}
            $OSDUpdateComponentDU = $OSDUpdateComponentDU | Sort-Object -Property CreationDate
            foreach ($Update in $OSDUpdateComponentDU) {
                if ($Update.OSDStatus -eq 'Downloaded') {
                    Write-Host "Ready       ComponentDU     $($Update.Title)"
                } else {
                    if ($Download.IsPresent) {
                        Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                    } else {
                        Write-Host "Missing     ComponentDU     $($Update.Title)" -ForegroundColor Yellow
                        $Execute = $false
                        $MissingUpdate = $true
                    }
                }
            }
            #===================================================================================================
            #   OSDBuilder Servicing Stack Update
            #===================================================================================================
            $OSDUpdateSSU = @()
            $OSDUpdateSSU = $OSDUpdates | Where-Object {$_.UpdateGroup -eq 'SSU'}
            $OSDUpdateSSU = $OSDUpdateSSU | Sort-Object -Property CreationDate
            #if ($OSMajorVersion -eq 10) {
                foreach ($Update in $OSDUpdateSSU) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       Servicing       $($Update.Title)"
                    } else {
                        if ($Download.IsPresent) {
                            Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                        } else {
                            Write-Host "Missing     Servicing       $($Update.Title)" -ForegroundColor Yellow
                            $Execute = $false
                            $MissingUpdate = $true
                        }
                    }
                }
            #}
            #===================================================================================================
            #   OSDBuilder Latest Cumulative Update
            #===================================================================================================
            $OSDUpdateLCU = @()
            #if ($OSMajorVersion -eq 10) {
                $OSDUpdateLCU = $OSDUpdates | Where-Object {$_.UpdateGroup -eq 'LCU'}
                $OSDUpdateLCU = $OSDUpdateLCU | Sort-Object -Property CreationDate
                foreach ($Update in $OSDUpdateLCU) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       Cumulative      $($Update.Title)"
                    } else {
                        if ($Download.IsPresent) {
                            Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                        } else {
                            Write-Host "Missing     Cumulative      $($Update.Title)" -ForegroundColor Yellow
                            $Execute = $false
                            $MissingUpdate = $true
                        }
                    }
                }
            #}
            #===================================================================================================
            #   OSDBuilder 10 Adobe
            #===================================================================================================
            $OSDUpdateAdobeSU = @()
            if ($OSMajorVersion -eq 10) {
                $OSDUpdateAdobeSU = $OSDUpdates | Where-Object {$_.UpdateGroup -eq 'AdobeSU'}
                $OSDUpdateAdobeSU = $OSDUpdateAdobeSU | Sort-Object -Property CreationDate
                foreach ($Update in $OSDUpdateAdobeSU) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       AdobeSU         $($Update.Title)"
                    } else {
                        if ($Download.IsPresent) {
                            Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                        } else {
                            Write-Host "Missing     AdobeSU         $($Update.Title)" -ForegroundColor Yellow
                            $Execute = $false
                            $MissingUpdate = $true
                        }
                    }
                }
            }
            #===================================================================================================
            #   OSDBuilder 10 DotNet
            #===================================================================================================
            $OSDUpdateDotNet = @()
            if ($OSMajorVersion -eq 10) {
                $OSDUpdateDotNet = $OSDUpdates | Where-Object {$_.UpdateGroup -like "DotNet*"}
                $OSDUpdateDotNet = $OSDUpdateDotNet | Sort-Object -Property CreationDate
                foreach ($Update in $OSDUpdateDotNet) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       DotNet          $($Update.Title)"
                    } else {
                        if ($Download.IsPresent) {
                            Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                        } else {
                            Write-Host "Missing     DotNet          $($Update.Title)" -ForegroundColor Yellow
                            $Execute = $false
                            $MissingUpdate = $true
                        }
                    }
                }
            }
            #===================================================================================================
            #   OSDBuilder Seven
            #===================================================================================================
            $OSDUpdateWinSeven = @()
            if ($MyInvocation.MyCommand.Name -eq 'Update-OSMedia' -and $UpdateOS -eq 'Windows 7') {
                $OSDUpdateWinSeven = $OSDUpdates
                $OSDUpdateWinSeven = $OSDUpdateWinSeven | Sort-Object -Property CreationDate
                foreach ($Update in $OSDUpdateWinSeven) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       Seven           $($Update.Title)"
                    } else {
                        if ($Download.IsPresent -and $_.UpdateGroup -ne 'Optional') {
                            Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                        } else {
                            Write-Host "Missing     Seven       $($Update.Title)" -ForegroundColor Yellow
                            if ($_.UpdateGroup -ne 'Optional') {
                                $Execute = $false
                                $MissingUpdate = $true
                            }
                        }
                    }
                }
            }
            #===================================================================================================
            #   OSDBuilder EightOne
            #===================================================================================================
            $OSDUpdateWinEightOne = @()
            if ($MyInvocation.MyCommand.Name -eq 'Update-OSMedia' -and $UpdateOS -eq 'Windows 8.1') {
                $OSDUpdateWinEightOne = $OSDUpdates
                $OSDUpdateWinEightOne = $OSDUpdateWinEightOne | Where-Object {$_.UpdateGroup -ne 'SetupDU'}
                $OSDUpdateWinEightOne = $OSDUpdateWinEightOne | Where-Object {$_.UpdateGroup -notlike "ComponentDU*"}
                $OSDUpdateWinEightOne = $OSDUpdateWinEightOne | Sort-Object -Property CreationDate
                foreach ($Update in $OSDUpdateWinEightOne) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       EightOne        $($Update.Title)"
                    } else {
                        if ($Download.IsPresent -and $_.UpdateGroup -ne 'Optional') {
                            Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                        } else {
                            Write-Host "Missing     EightOne        $($Update.Title)" -ForegroundColor Yellow
                            if ($_.UpdateGroup -ne 'Optional') {$Execute = $false}
                        }
                    }
                }
            }
            #===================================================================================================
            #   OSDBuilder Twelve
            #===================================================================================================
            $OSDUpdateWinTwelveR2 = @()
            if ($MyInvocation.MyCommand.Name -eq 'Update-OSMedia' -and $UpdateOS -eq 'Windows Server 2012 R2') {
                $OSDUpdateWinTwelveR2 = $OSDUpdates
                $OSDUpdateWinTwelveR2 = $OSDUpdateWinTwelveR2 | Where-Object {$_.UpdateGroup -ne 'SetupDU'}
                $OSDUpdateWinTwelveR2 = $OSDUpdateWinTwelveR2 | Where-Object {$_.UpdateGroup -notlike "ComponentDU*"}
                $OSDUpdateWinTwelveR2 = $OSDUpdateWinTwelveR2 | Sort-Object -Property CreationDate
                foreach ($Update in $OSDUpdateWinTwelveR2) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       TwelveR2        $($Update.Title)"
                    } else {
                        if ($Download.IsPresent -and $_.UpdateGroup -ne 'Optional') {
                            Get-OSDUpdateDownloads -OSDGuid $Update.OSDGuid
                        } else {
                            Write-Host "Missing     TwelveR2        $($Update.Title)" -ForegroundColor Yellow
                            if ($_.UpdateGroup -ne 'Optional') {$Execute = $false}
                        }
                    }
                }
            }
            #===================================================================================================
            #   OSDBuilder Optional
            #===================================================================================================
            $OSDUpdateOptional = @()
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and $OSMajorVersion -eq 10) {
                $OSDUpdateOptional = $OSDUpdates | Where-Object {$_.UpdateGroup -eq ''}
                $OSDUpdateOptional = $OSDUpdateOptional | Sort-Object -Property CreationDate
                foreach ($Update in $OSDUpdateOptional) {
                    if ($Update.OSDStatus -eq 'Downloaded') {
                        Write-Host "Ready       Optional        $($Update.Title)"
                    } else {
                        Write-Host "Missing     Optional        $($Update.Title)" -ForegroundColor Yellow
                    }
                }
            }
            #===================================================================================================
            #   Update Check
            #===================================================================================================
            if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild' -and $LatestOSMedia) {
                if ($LatestOSMedia.Updates -ne 'OK') {
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    Write-Warning "This OSMedia does not have the latest Microsoft Updates"
                    Write-Warning "Use the following command before running New-OSBuild"
                    Write-Warning "Update-OSMedia -Name `'$OSMediaName`' -Download -Execute"
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                }
            }
            #===================================================================================================
            #   Execution Check
            #===================================================================================================
            if ($MissingUpdate -eq $true) {
                Write-Warning "Execution is currently disabled because one or more updates are missing"
            } elseif ($Execute -eq $false) {
                Write-Warning "Execution is disabled without the -Execute parameter"
            }
            #===================================================================================================
            if ($Execute.IsPresent) {
                #===================================================================================================
                Write-Verbose '19.1.25 Remove Existing WorkingPath'
                #===================================================================================================
                if (Test-Path $WorkingPath) {
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    Remove-Item -Path "$WorkingPath" -Force -Recurse
                }
                #===================================================================================================
                Write-Verbose '19.2.25 Set Variables'
                #===================================================================================================
                $MountDirectory = Join-Path $SetOSDBuilderPathMount "os$((Get-Date).ToString('mmss'))"
                $MountWinPE = Join-Path $SetOSDBuilderPathMount "winpe$((Get-Date).ToString('mmss'))"
                $MountWinRE = Join-Path $SetOSDBuilderPathMount "winre$((Get-Date).ToString('mmss'))"
                $MountWinSE = Join-Path $SetOSDBuilderPathMount "setup$((Get-Date).ToString('mmss'))"
                $Info = Join-Path $WorkingPath 'info'
                    $Logs = Join-Path $Info 'logs'
                $OS = Join-Path $WorkingPath 'OS'
                $WimTemp = Join-Path $WorkingPath "WimTemp"
                $WinPE = Join-Path $WorkingPath 'WinPE'
                    $PEInfo = Join-Path $WinPE 'info'
                    $PELogs = Join-Path $PEInfo 'logs'
                #===================================================================================================
                Write-Verbose '19.1.1 Start Transcript'
                #===================================================================================================
                Write-Host '========================================================================================' -ForegroundColor DarkGray
                $ScriptName = $($MyInvocation.MyCommand.Name)
                $LogName = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$ScriptName.log"
                Start-Transcript -Path (Join-Path "$Info\logs" $LogName)
                #===================================================================================================
                #   Update-OSMedia and New-OSBuild
                #===================================================================================================
                New-DirectoriesOSMedia
                Show-WorkingInfoOS
                Copy-MediaOperatingSystem
                #===================================================================================================
                #   WinPE
                #===================================================================================================
                Update-SetupDUMEDIA
                Mount-WinPEwim -OSMediaPath "$WorkingPath"
                Mount-WinREwim -OSMediaPath "$WorkingPath"
                Mount-WinSEwim -OSMediaPath "$WorkingPath"
                #===================================================================================================
                #   WinPE ADK
                #===================================================================================================
                $global:ReapplyLCU = $false
                $global:UpdateLanguageContent = $false
                Add-ContentADKWinPE
                Add-ContentADKWinRE
                Add-ContentADKWinSE
                Add-ContentPack -PackType PEADK
                Add-ContentPack -PackType PEADKLang
                #===================================================================================================
                #   WinPE DaRT
                #===================================================================================================
                Expand-DaRTPE
                Add-ContentPack -PackType PEDaRT
                #===================================================================================================
                #   WinPE Updates
                #===================================================================================================
                Update-ServicingStackPE
                Update-CumulativePE
                #===================================================================================================
                #   WinPE Content
                #===================================================================================================
                Import-AutoExtraFilesPE
                Add-ContentExtraFilesPE
                Add-ContentDriversPE
                Add-ContentScriptsPE
                Add-ContentPack -PackType PEDrivers
                Add-ContentPack -PackType PEExtraFiles
                Add-ContentPack -PackType PEPoshMods
                Add-ContentPack -PackType PERegistry
                Add-ContentPack -PackType PEScripts
                #===================================================================================================
                #   Update-OSMedia and New-OSBuild
                #===================================================================================================
                Update-SourcesPE -OSMediaPath "$WorkingPath"
                Save-PackageInventoryPE -OSMediaPath "$WorkingPath"
                if ($PauseDismountPE.IsPresent){[void](Read-Host 'Press Enter to Continue')}
                Dismount-WimsPE -OSMediaPath "$WorkingPath"
                Export-PEWims -OSMediaPath "$WorkingPath"
                Export-PEBootWim -OSMediaPath "$WorkingPath"
                Save-InventoryPE -OSMediaPath "$WorkingPath"
                #===================================================================================================
                #   Install.wim
                #===================================================================================================
                Mount-InstallwimOS
                Set-WinREWimOS
                #===================================================================================================
                #   Install.wim UBR Pre-Update
                #===================================================================================================
                Show-ActionTime
                Write-Host -ForegroundColor Green "OS: Mount Registry for UBR Information"
                reg LOAD 'HKLM\OSMedia' "$MountDirectory\Windows\System32\Config\SOFTWARE" | Out-Null
                $RegKeyCurrentVersion = Get-ItemProperty -Path 'HKLM:\OSMedia\Microsoft\Windows NT\CurrentVersion'
                reg UNLOAD 'HKLM\OSMedia' | Out-Null
                if ($($RegKeyCurrentVersion.ReleaseId)) {$ReleaseId = $($RegKeyCurrentVersion.ReleaseId)}
                if ($($RegKeyCurrentVersion.CurrentBuild)) {$RegValueCurrentBuild = $($RegKeyCurrentVersion.CurrentBuild)}
                else {$RegValueCurrentBuild = $OSSPBuild}
                if ($($RegKeyCurrentVersion.UBR)) {$RegValueUbr = $($RegKeyCurrentVersion.UBR)}
                else {$RegValueUbr = $OSSPBuild}
                $UBR = "$RegValueCurrentBuild.$RegValueUbr"
                Save-RegistryCurrentVersionOS
                $UBRPre = $UBR
                #===================================================================================================
                #   Language Content
                #===================================================================================================
                Add-LanguagePacksOS
                Add-ContentPack -PackType OSLanguagePacks
                Add-LanguageInterfacePacksOS
                Add-LanguageFeaturesOnDemandOS
                Add-ContentPack -PackType OSLanguageFeatures
                Add-LocalExperiencePacksOS
                Add-ContentPack -PackType OSLocalExperiencePacks
                Copy-MediaLanguageSources
                Add-ContentPack -PackType MEDIA
                if ($LanguagePacks -or $LanguageInterfacePacks -or $LanguageFeatures -or $LocalExperiencePacks -or ($global:UpdateLanguageContent -eq $true)) {
                    Set-LanguageSettingsOS
                    #Update-CumulativeOS -Force
                    #if ($HideCleanupProgress.IsPresent) {Invoke-DismCleanupImage -HideCleanupProgress} else {Invoke-DismCleanupImage}
                }
                #===================================================================================================
                #   Optional Content
                #===================================================================================================
                Add-ContentPack -PackType OSCapability
                Add-ContentPack -PackType OSPackages
                Add-WindowsPackageOS
                Add-FeaturesOnDemandOS
                #===================================================================================================
                #   Install.wim Updates
                #===================================================================================================
                Update-ComponentOS
                Update-ServicingStackOS
                #===================================================================================================
                #   Install.wim UBR Post-Update
                #===================================================================================================
                Show-ActionTime; Write-Host -ForegroundColor Green "OS: Update Build Revision $UBRPre (Pre-LCU)"
                Update-CumulativeOS -Force
                #===================================================================================================
                #   Update-OSMedia
                #===================================================================================================
                Update-WindowsSevenOS
                Update-WindowsServer2012R2OS
                #===================================================================================================
                #   Install.wim UBR Post-Update
                #===================================================================================================
                reg LOAD 'HKLM\OSMedia' "$MountDirectory\Windows\System32\Config\SOFTWARE" | Out-Null
                $RegKeyCurrentVersion = Get-ItemProperty -Path 'HKLM:\OSMedia\Microsoft\Windows NT\CurrentVersion'
                reg UNLOAD 'HKLM\OSMedia' | Out-Null
                if ($($RegKeyCurrentVersion.ReleaseId)) {$ReleaseId = $($RegKeyCurrentVersion.ReleaseId)}
                if ($($RegKeyCurrentVersion.CurrentBuild)) {$RegValueCurrentBuild = $($RegKeyCurrentVersion.CurrentBuild)}
                else {$RegValueCurrentBuild = $OSSPBuild}
                if ($($RegKeyCurrentVersion.UBR)) {$RegValueUbr = $($RegKeyCurrentVersion.UBR)}
                else {$RegValueUbr = $OSSPBuild}
                $UBR = "$RegValueCurrentBuild.$RegValueUbr"
                Save-RegistryCurrentVersionOS
                Show-ActionTime
                Write-Host -ForegroundColor Green "OS: Update Build Revision $UBR (Post-LCU)"
                #===================================================================================================
                #   Update-OSMedia and New-OSBuild
                #===================================================================================================
                Update-AdobeOS
                Update-DotNetOS
                Update-OptionalOS
                #===================================================================================================
                #   OneDriveSetup
                #===================================================================================================
                if ($OSMajorVersion -eq 10 -and $OSInstallationType -eq 'Client') {
                    Show-ActionTime
                    Write-Host -ForegroundColor Green "OS: Update OneDriveSetup.exe"
                    $OneDriveSetupDownload = $false
                    $OneDriveSetup = Join-Path $GetOSDBuilderPathContentOneDrive 'OneDriveSetup.exe'
                    if (!(Test-Path $OneDriveSetup)) {$OneDriveSetupDownload = $true}

                    if (Test-Path $OneDriveSetup) {
                        if (!(([System.Io.fileinfo]$OneDriveSetup).LastWriteTime.Date -ge [datetime]::Today )) {
                            $OneDriveSetupDownload = $true
                        }
                    }
<#                     if ($OneDriveSetupDownload -eq $true) {
                        $WebClient = New-Object System.Net.WebClient
                        Write-Host "Downloading to $OneDriveSetup" -ForegroundColor Gray
                        $WebClient.DownloadFile('https://go.microsoft.com/fwlink/p/?LinkId=248256',"$OneDriveSetup")
                    } #>

                    if ($OSArchitecture -eq 'x86') {
                        $OneDriveSetupInfo = Get-Item -Path "$MountDirectory\Windows\System32\OneDriveSetup.exe" | Select-Object -Property *
                        Write-Host -ForegroundColor Gray "                  Install.wim version $($($OneDriveSetupInfo).VersionInfo.ProductVersion)"
                        if (Test-Path $OneDriveSetup) {
                            robocopy "$GetOSDBuilderPathContentOneDrive" "$MountDirectory\Windows\System32" OneDriveSetup.exe /ndl /xx /b /np /ts /tee /r:0 /w:0 /Log+:"$Info\logs\$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Update-OneDriveSetup.log" | Out-Null
                            $OneDriveSetupInfo = Get-Item -Path "$MountDirectory\Windows\System32\OneDriveSetup.exe" | Select-Object -Property *
                            Write-Host -ForegroundColor Gray "                  Updated version $($($OneDriveSetupInfo).VersionInfo.ProductVersion)"
                        }
                    } else {
                        $OneDriveSetupInfo = Get-Item -Path "$MountDirectory\Windows\SysWOW64\OneDriveSetup.exe" | Select-Object -Property *
                        Write-Host -ForegroundColor Gray "                  Install.wim version $($($OneDriveSetupInfo).VersionInfo.ProductVersion)"
                        if (Test-Path $OneDriveSetup) {
                            robocopy "$GetOSDBuilderPathContentOneDrive" "$MountDirectory\Windows\SysWOW64" OneDriveSetup.exe /ndl /xx /b /np /ts /tee /r:0 /w:0 /Log+:"$Info\logs\$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Update-OneDriveSetup.log" | Out-Null
                            $OneDriveSetupInfo = Get-Item -Path "$MountDirectory\Windows\SysWOW64\OneDriveSetup.exe" | Select-Object -Property *
                            Write-Host -ForegroundColor Gray "                  Updated version $($($OneDriveSetupInfo).VersionInfo.ProductVersion)"
                        }
                    }
                    Write-Host -ForegroundColor Cyan "                  To update OneDriveSetup.exe use one of the following commands:"
                    Write-Host -ForegroundColor Cyan "                  Get-DownOSDBuilder -ContentDownload 'OneDriveSetup Enterprise'"
                    Write-Host -ForegroundColor Cyan "                  Get-DownOSDBuilder -ContentDownload 'OneDriveSetup Production'"
                }
                #===================================================================================================
                #	DismCleanupImage
                #===================================================================================================
                if ($HideCleanupProgress.IsPresent) {Invoke-DismCleanupImage -HideCleanupProgress} else {Invoke-DismCleanupImage}
                #===================================================================================================
                #   Content
                #===================================================================================================
                Enable-WindowsOptionalFeatureOS
                Enable-NetFXOS
                Remove-AppxProvisionedPackageOS
                Remove-WindowsPackageOS
                Remove-WindowsCapabilityOS
                Disable-WindowsOptionalFeatureOS
                Add-ContentDriversOS
                Add-ContentExtraFilesOS
                Add-ContentStartLayout
                Add-ContentUnattend
                Add-ContentScriptsOS
                Import-RegistryRegOS
                Import-RegistryXmlOS
                Add-ContentPack -PackType OSDrivers
                Add-ContentPack -PackType OSExtraFiles
                Add-ContentPack -PackType OSPoshMods
                Add-ContentPack -PackType OSRegistry
                Add-ContentPack -PackType OSScripts
                Add-ContentPack -PackType OSStartLayout
                #===================================================================================================
                #	Updates
                #===================================================================================================
                #Update-ServicingStackOS -Force
                #===================================================================================================
                #	Mirror OSMedia and OSBuild
                #===================================================================================================
                Save-AutoExtraFilesOS -OSMediaPath "$WorkingPath"
                Save-SessionsXmlOS -OSMediaPath "$WorkingPath"
                Save-InventoryOS -OSMediaPath "$WorkingPath"
                #===================================================================================================
                #   Dismount
                #===================================================================================================
                if ($PauseDismountOS.IsPresent){[void](Read-Host 'Press Enter to Continue')}
                Dismount-InstallwimOS
                Export-InstallwimOS
                #===================================================================================================
                Write-Verbose '19.1.1 OS: Export Configuration'
                #===================================================================================================
                Show-ActionTime
                Write-Host -ForegroundColor Green "OS: Export Configuration to $WorkingPath\WindowsImage.txt"
                $GetWindowsImage = @()
                $GetWindowsImage = Get-WindowsImage -ImagePath "$OS\sources\install.wim" -Index 1 | Select-Object -Property *

                Write-Verbose "========== SPBuild: $($GetWindowsImage.Build).$($GetWindowsImage.SPBuild)"
                if ($OSVersion -like "6.*") {
                    Write-Verbose '========== Windows 6.x'
                    $UBR = "$($GetWindowsImage.Build).$($GetWindowsImage.SPBuild)"
                }
                Write-Verbose "========== UBR: $UBR"

                $GetWindowsImage | Add-Member -Type NoteProperty -Name "UBR" -Value $UBR
                $GetWindowsImage | Out-File "$WorkingPath\WindowsImage.txt"
                $GetWindowsImage | Out-File "$Info\logs\$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Get-WindowsImage.txt"
                $GetWindowsImage | Export-Clixml -Path "$Info\xml\Get-WindowsImage.xml"
                $GetWindowsImage | Export-Clixml -Path "$Info\xml\$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Get-WindowsImage.xml"
                $GetWindowsImage | ConvertTo-Json | Out-File "$Info\json\Get-WindowsImage.json"
                $GetWindowsImage | ConvertTo-Json | Out-File "$Info\json\$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Get-WindowsImage.json"
                (Get-Content "$WorkingPath\WindowsImage.txt") | Where-Object {$_.Trim(" `t")} | Set-Content "$WorkingPath\WindowsImage.txt"
                
                #===================================================================================================
                #    OSD-Export
                #===================================================================================================
                #Save-WindowsImageContentPE

                #===================================================================================================
                Write-Verbose '19.3.17 UBR Validation'
                #===================================================================================================
                if ($MyInvocation.MyCommand.Name -eq 'Update-OSMedia') {
                    if ($UBRPre -eq $UBR) {
                        Write-Host '========================================================================================' -ForegroundColor DarkGray
                        Write-Warning 'The Update Build Revision did not change after Windows Updates'
                        Write-Warning 'There may have been an issue applying the Latest Cumulative Update if this was not expected'
                    }
                }
                if (!($UBR)) {
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    $UBR = $((Get-Date).ToString('mmss'))
                    Write-Warning 'Could not determine a UBR'
                }

                #===================================================================================================
                Write-Verbose '19.1.1 Remove Temporary Files'
                #===================================================================================================
                if (Test-Path "$WimTemp") {Remove-Item -Path "$WimTemp" -Force -Recurse | Out-Null}
                if (Test-Path "$MountDirectory") {Remove-Item -Path "$MountDirectory" -Force -Recurse | Out-Null}
                if (Test-Path "$MountWinRE") {Remove-Item -Path "$MountWinRE" -Force -Recurse | Out-Null}
                if (Test-Path "$MountWinPE") {Remove-Item -Path "$MountWinPE" -Force -Recurse | Out-Null}
                if (Test-Path "$MountWinSE") {Remove-Item -Path "$MountWinSE" -Force -Recurse | Out-Null}

                #===================================================================================================
                Write-Verbose '19.1.1 Set New Name'
                #===================================================================================================
                $OSImageName = $($GetWindowsImage.ImageName)
                $OSImageName = $OSImageName -replace '\(', ''
                $OSImageName = $OSImageName -replace '\)', ''

                $OSArchitecture = $($GetWindowsImage.Architecture)
                if ($OSArchitecture -eq '0') {$OSArchitecture = 'x86'}
                if ($OSArchitecture -eq '6') {$OSArchitecture = 'ia64'}
                if ($OSArchitecture -eq '9') {$OSArchitecture = 'x64'}
                if ($OSArchitecture -eq '12') {$OSArchitecture = 'x64 ARM'}

                $OSBuild = $($GetWindowsImage.Build)
                $ReleaseId = $null
                if (Test-Path "$Info\xml\CurrentVersion.xml") {
                    $RegKeyCurrentVersion = Import-Clixml -Path "$Info\xml\CurrentVersion.xml"
                    $ReleaseId = $($RegKeyCurrentVersion.ReleaseId)
                }
                if ($OSBuild -eq 7600) {$ReleaseId = 7600}
                if ($OSBuild -eq 7601) {$ReleaseId = 7601}
                if ($OSBuild -eq 9600) {$ReleaseId = 9600}
                if ($OSBuild -eq 10240) {$ReleaseId = 1507}
                if ($OSBuild -eq 14393) {$ReleaseId = 1607}
                if ($OSBuild -eq 15063) {$ReleaseId = 1703}
                if ($OSBuild -eq 16299) {$ReleaseId = 1709}
                if ($OSBuild -eq 17134) {$ReleaseId = 1803}
                if ($OSBuild -eq 17763) {$ReleaseId = 1809}
				#if ($OSBuild -eq 18362) {$ReleaseId = 1903}


                if ($OSMajorVersion -eq 10) {
                    if ($WorkingName -like "build*") {$NewOSMediaName = "$OSImageName $OSArchitecture $ReleaseId $UBR"}
                } else {
                    if ($WorkingName -like "build*") {$NewOSMediaName = "$OSImageName $OSArchitecture $UBR"}
                }

                $OSLanguages = $($GetWindowsImage.Languages)

                $NewOSMediaName = "$NewOSMediaName $OSLanguages"
                if ($($OSLanguages.count) -eq 1) {$NewOSMediaName = $NewOSMediaName.replace(' en-US','')}

                if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild') {
                    if ($CustomName) {$NewOSMediaName = "$CustomName $UBR"}
                }
                
                if ($MyInvocation.MyCommand.Name -eq 'Update-OSMedia') {$NewOSMediaPath = "$SetOSDBuilderPathOSMedia\$NewOSMediaName"}
                if ($MyInvocation.MyCommand.Name -eq 'New-OSBuild') {$NewOSMediaPath = "$SetOSDBuilderPathOSBuilds\$NewOSMediaName"}

                #===================================================================================================
                Write-Verbose '19.1.1 Rename Build Directory'
                #===================================================================================================
                if (Test-Path $NewOSMediaPath) {
                    $mmss = $((Get-Date).ToString('mmss'))
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    Write-Warning 'Trying to rename the Build directory, but it already exists'
                    Write-Warning "Appending $mmss to the directory Name"
                    Write-Host '========================================================================================' -ForegroundColor DarkGray
                    $NewOSMediaName = "$NewOSMediaName $mmss"
                    $NewOSMediaPath = "$SetOSDBuilderPathOSMedia\$NewOSMediaName"
                }
                #===================================================================================================
                #   OSD-Export
                #===================================================================================================
                Save-WindowsImageContentOS
                Save-VariablesOSD
                #===================================================================================================
                #   OSDBuilder Media'
                #===================================================================================================
                if ($CreateISO.IsPresent) {New-OSDBuilderISO -FullName "$WorkingPath"}
                if ($OSDVHD.IsPresent) {New-OSDBuilderVHD -FullName "$WorkingPath"}
                if ($OSDInfo.IsPresent) {Show-OSDBuilderInfo -FullName "$WorkingPath"}
                #===================================================================================================
                #   Complete Update
                #===================================================================================================
				#===================================================================================================
				#   Header
				#===================================================================================================
				Show-ActionTime
				Write-Host -ForegroundColor Green "Media: Renaming ""$WorkingPath"" to ""$NewOSMediaName"""
                Write-Host '========================================================================================' -ForegroundColor DarkGray
                Stop-Transcript
                try {
                    Rename-Item -Path "$WorkingPath" -NewName "$NewOSMediaName"
                }
                catch {
                    Write-Warning "Could not rename the the Build directory ... Waiting 30 seconds ..."
                    Start-Sleep -Seconds 30
                }
                if (Test-Path "$WorkingPath") {
                    try {
                        Rename-Item -Path "$WorkingPath" -NewName "$NewOSMediaName"
                    }
                    catch {
                        Write-Warning "Could not rename the the Build directory ... Existing"
                        Exit
                    }
                }
            }
        }
    }

    END {
        #Write-Host '========================================================================================' -ForegroundColor DarkGray
        #Write-Host -ForegroundColor Green "$($MyInvocation.MyCommand.Name) END"
    }
}