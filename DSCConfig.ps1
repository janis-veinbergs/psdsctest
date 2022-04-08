[DSCLocalConfigurationManager()]
configuration DSCConfig
{
    Node $AllNodes.NodeName
    {
        Settings
        {
            #allow reboot with PendingReboot resource from ComputerManagementDsc module
            RebootNodeIfNeeded = $true
        }
    }
}