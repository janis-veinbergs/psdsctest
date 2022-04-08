# We will be able to call this configuration as a resource. Not using any non-OOTB resources. We must be able to run this on bare host.
Configuration InstallPSModule {
    param (
        [parameter(Mandatory)]
        [string]$ModuleName,
        [parameter(Mandatory)]
        [string]$RequiredVersion
    )

    Import-DscResource -Module "PSDesiredStateConfiguration" -Name "Script"
    
    Script TrustRepository {
        GetScript =  { @{Result="$((Get-PSRepository -Name PSGallery -ErrorAction Ignore) -and (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore))"} }
        TestScript = { (Get-PSRepository -Name PSGallery -ErrorAction Ignore) -and (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore) }
        SetScript = {
            Install-PackageProvider -Name NuGet -Force
            Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/ -InstallationPolicy Trusted -PackageManagementProvider NuGet
        }
    }

    Script InstallPSModulesDsc {
        GetScript =  {
            $module = Get-Module -Name "$using:ModuleName" -ListAvailable
            @{Result="$($module.Name); Version=$($module.Version)"}
        }
        TestScript = { (Get-Module -Name "$using:ModuleName" -ListAvailable | ? {$_.Version -eq "$using:RequiredVersion"} | measure | select -ExpandProperty Count) -eq 1 }
        SetScript = { Install-Module -Name "$using:ModuleName" -RequiredVersion "$using:RequiredVersion" -Force }
        DependsOn = "[Script]TrustRepository" 
    }
}


<#
.SYNOPSIS
    Install required modules. Thus, this must be run first.
#>
Configuration InstallPSModules {
    Node $AllNodes.NodeName
	{
        InstallPSModule PSDscResources { ModuleName="PSDscResources"; RequiredVersion="2.12.0.0"} 
        InstallPSModule CertificateDsc { ModuleName="CertificateDsc"; RequiredVersion="5.1.0"} 
    }
}