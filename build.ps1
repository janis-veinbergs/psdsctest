<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build

    Doesn't require any module to be installed, but will install Invoke-Build and required modules for PowerShell DSC to do build and deploy.
.Example
    List available commands

	PS> ./build.ps1 ?

    Name                   Jobs                                                                 Synopsis
    ----                   ----                                                                 --------
    deployDSCConfig        {buildDSCConfig, {}}                                                 Apply DSC engine configuration to allow reboots. Kind of a special case: https://docs.mi... 
    installModules         {}                                                                   Install required powershell modules for current host for build to work.
    buildDSCConfig         {}                                                                   Generate .mof files configuring local DSC settings
    buildInstallPSModules  {}                                                                   Generate .mof files for PowerShell module installation for passed nodes (prerequisite fo...
    buildConfig            {}                                                                   Generates sample config
    build                  {installModules, buildDSCConfig, buildInstallPSModules, buildConfig} Build project. Build will call all those other taskkks
    deploy                 {clean, build, deployDSCConfig, deployInstallPSModules...}           Deploy will push configuration to nodes. Will call build before.
    deployInstallPSModules {buildInstallPSModules, {}}                                          Deploy only module installation. Will push configuration to nodes. Will call build befor... 
    deployConfig           {buildConfig, {}}                                                    Deploy only config, without installing required modules. Will push configuration to node... 
    clean                  {}                                                                   Remove *.mof files.
    .                      build                                                                Default task.

.Example 
    Passing credentials if current user doesn't have permissions to push config
    
    PS> .\build.ps1 deploy -Nodes localhost -Credential (Get-Credential) 


.Parameter Tasks
    Invoke-Build tasks to run.
.Parameter Credential
    If provided, Start-DscConfiguration (for deploy* tasks) will be passed using specified account. If null, will use current account.
.Parameter Nodes
    To which nodes build and deploy tasks are applied.
#>

param(
	[Parameter(Position=0)]
	[string[]]$Tasks,
	[string[]]$Nodes,
    [PSCredential]$Credential
)

# Ensure and call the module.
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
	$InvokeBuildVersion = '5.9.9.0'
	$ErrorActionPreference = 'Stop'
	try {
		Import-Module InvokeBuild -RequiredVersion $InvokeBuildVersion
	}
	catch {
		Install-Module InvokeBuild -RequiredVersion $InvokeBuildVersion -Scope CurrentUser -Force
		Import-Module InvokeBuild -RequiredVersion $InvokeBuildVersion
	}
	Invoke-Build -Task $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
	return
}

#Separating Configuration data from configuration: https://docs.microsoft.com/en-us/powershell/dsc/configurations/configdata?view=dsc-1.1
$configurationData = @{AllNodes=@(
    $Nodes | % { @{NodeName=$_} }
)};

#Synopsis: Apply DSC engine configuration to allow reboots. Kind of a special case: https://docs.microsoft.com/en-us/powershell/dsc/managing-nodes/metaconfig?view=dsc-1.1
task deployDSCConfig buildDSCConfig, {
	exec {
		Set-DscLocalConfigurationManager .\DSCConfig\ -ComputerName $Nodes -Verbose
	}
}

#Synopsis: Install required powershell modules for current host for build to work.
task installModules {
	exec -ExitCode 0,141 {
		# Install resources on build agent
		"Installing required resources on build agent...."

		if(!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
			Install-PackageProvider -Name NuGet -Force
		}
		if (!(Get-PSRepository -Name PSGallery -ErrorAction Ignore)) {
			Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/ -InstallationPolicy Trusted -PackageManagementProvider NuGet
		}
        
        $RequiredModules = @(
			@{ ModuleName="PSDscResources"; RequiredVersion="2.12.0.0"} 
            @{ ModuleName="CertificateDsc"; RequiredVersion="5.1.0"}
		)
		if ($PSVersionTable.PSVersion -ge 6.1) {
			$RequiredModules += @{ ModuleName="PSDesiredStateConfiguration"; RequiredVersion="2.0.5"} 
		}
		$availableModules = Get-Module -ListAvailable
		$RequiredModules | ? { $requiredModule = $_; ($availableModules | ? {$_.Name -eq $requiredModule.ModuleName -and $_.Version -eq $requiredModule.RequiredVersion} | Measure-Object).Count -eq 0 } `
		| % {
			Write-Output "Installing $($_.ModuleName) v$($_.RequiredVersion)"
			Install-Module -Name $_.ModuleName -RequiredVersion $_.RequiredVersion -Repository 'PSGallery' -Force
		}
        
		$global:LastExitCode = 0
	}
}


# Synopsis: Generate .mof files configuring local DSC settings
task buildDSCConfig {
	exec {
		if ($Nodes -eq $null) {
			Write-Warning "No -Nodes passed to build - will not build new ones"
			return
		}

		. .\DSCConfig.ps1
		DSCConfig -ConfigurationData $configurationData
	}
}

# Synopsis: Generate .mof files for PowerShell module installation for passed nodes (prerequisite for setupIisServers configuration)
task buildInstallPSModules {
	exec {
		if ($Nodes -eq $null) {
			Write-Warning "No -Nodes passed to build - will not build new ones"
			return
		}

		. .\InstallPSModules.ps1
		InstallPSModules -ConfigurationData $configurationData
	}
}

# Synopsis: Generates sample config
task buildConfig {
	exec {
		if ($Nodes -eq $null) {
			Write-Warning "No -Nodes passed to build - will not build new ones"
			return
		}

		. .\SampleConfig.ps1
		SampleConfig -ConfigurationData $configurationData
	}
}

# Synopsis: Build project. Build will call all those other taskkks
task build installModules, buildDSCConfig, buildInstallPSModules, buildConfig
# Synopsis: Deploy will push configuration to nodes. Will call build before.
task deploy clean, build, deployDSCConfig, deployInstallPSModules, deployConfig

# Synopsis: Deploy only module installation. Will push configuration to nodes. Will call build before deploy.
task deployInstallPSModules buildInstallPSModules,   {
	exec { Start-DscConfiguration .\InstallPSModules\ -ComputerName $Nodes -wait -Verbose -Force -Credential $Credential }
}

# Synopsis: Deploy only config, without installing required modules. Will push configuration to nodes. Will call build before deploy.
task deployConfig buildConfig, {
    exec { Start-DscConfiguration .\SampleConfig\ -ComputerName $Nodes -wait -Verbose -Force -Credential $Credential }
}

# Synopsis: Remove *.mof files.
task clean {
	exec {
		Get-ChildItem . -Recurse -Filter *.mof | Remove-Item -Verbose
		$global:LastExitCode = 0
	}
}

# Synopsis: Default task.
task . build

