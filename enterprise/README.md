# Deploying Scality Connect with Linux VM Scale Set

The following template deploys a Linux VM Scale Set to run Scality Connect as an
enterprise solution.

The template deploys a Linux VMSS with a level 4 load balancer (which will be the
endpoint that users send requests to) and the number of VM instances specified
in `azuredeploy.parameters.json`.

Each VM instance will have Scality Connect running. The user will have to provide
the proper credentials for a pre-existing storage account upon startup.

We do not enable auto-scaling. The admin has control of how many VM's are running
at all times. To scale up, simply go to the Azure portal and add an instance.
The instance will come on line and Scality Connect will be running without the
admin having to ssh into the machine.

Before we begin, you should have the following:

- a valid domain name
- SSL certificates associated with the domain name and signed by a certificate
authority
- A valid VHD image (Please contact Scality) stored in your Azure account, in the
same region as your deployment.

To deploy this template from the command line, please make a copy of
`connectdeploy.sample.template.json` and rename as `azuredeploy.parameters.json`.

Run the `keyvault.sh` to upload your private key and corresponding .crt file to
keyvault.

```
./keyvault.sh <keyvaultname> <resource group name> <location> <secretName> \
    <certpemfile> <keyfile>
```

The script automatically replaces any dummy values in `azuredeploy.parameters.json`
starting with "REPLACE_".

For your remaining certificates, please upload them to a blob storage account.
Generate a SAS url to be set as the `CACertSAS` parameter value during deployment.

Note: Use the same location (or region, such as Central US, West Central US) for all
your resources - VHD image, Key Vault, and final deployment.

Update the remaining values in `azuredeploy.parameters.json` to your deployment
values, then run the following commands:

```
# Create a new resource group in your preferred location (or use an existing rg)
az group create --name examplegroup --location "yourfavoritelocation"
# Execute the following command, with the correct resource group name
az group deployment create \
    --name ExampleDeployment \
    --resource-group examplegroup \
    --template-file azuredeploy.json \
    --parameters @azuredeploy.parameters.json
```

To deploy this template through the Azure portal web interface, please use the
"Deploy to Azure" button at the bottom of this page.

[![](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FScality%2Fazure-templates%2Fssl-cert%2Fenterprise%2Fazuredeploy.json)
