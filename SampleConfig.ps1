configuration SampleConfig {    
    Import-DscResource -Module PackageManagement -ModuleVersion 1.0.0.1
    Import-DscResource -Module CertificateDsc -ModuleVersion 5.1.0

    Node $AllNodes.NodeName {               
        $DNSName = "example.com"
        CertReq SSLCert {
            Subject             = $DNSName; SubjectAltName = "dns=$DNSName&dns=www.$DNSName"
            FriendlyName        = $DNSName
            Exportable          = $true
            ProviderName        = 'Microsoft RSA SChannel Cryptographic Provider'; KeyUsage = '0xa0'; OID = '1.3.6.1.5.5.7.3.1' #serverAuth
            KeyLength           = '2048'
            CertificateTemplate = 'WebServer'
            KeyType             = 'RSA'
            RequestType         = 'CMC'
        }
    } 
}