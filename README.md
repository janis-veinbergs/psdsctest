# PowerShell DSC - Infrastructure as Code. Work-around pain points.

Show how to initiate PowerShell DSC configuration with one-single command. Includes configuration of DSC Engine and module dependency installation.

Available tasks:
```powershell
./build.ps1 ?

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
    .                      build                                                                Default task
```

Invoking deployment:
```powershell 
.\build.ps1 deploy -Nodes localhost -Credential (Get-Credential) 
```