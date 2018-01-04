#!/bin/bash

#set -e

usage()
{
    echo usage: keyvault.sh '<keyvaultname> <resource group name> <location> <secretname> <certpemfile> <keyfile>'
    echo The cacertpem file is optional. The template will accept a self-signed cert and key.
}

creategroup()
{

    az group show $rgname 2> /dev/null
    if [ $? -eq 0 ]
    then
        echo Resource Group $rgname already exists. Skipping creation.
    else
        # Create a resource group for the keyvault
        az group create -n $rgname -l $location
    fi

}

createkeyvault()
{

    az keyvault show $vaultname 2> /dev/null
    if [ $? -eq 0 ]
    then
        echo Key Vault $vaultname already exists. Skipping creation.
    else
        echo Creating Key Vault $vaultname.

        creategroup
        # Create the key vault
        az keyvault create --name $vaultname --resource-group $rgname --location $location
    fi

    #az keyvault set-policy --name $vaultname --resource-group $rgname --certificate-permissions {get, list} --key-permissions {get, list}
    az keyvault update --name $vaultname --resource-group $rgname --enabled-for-template-deployment true --enabled-for-deployment true --enabled-for-disk-encryption true
}

convertcacert()
{
    local cert=$1
    local key=$2
    local pfxfile=$3
    local pass=$4

    echo Creating PFX $pfxfile
    openssl pkcs12 -export -out $pfxfile -inkey $key -in $cert -password pass:$pass 2> /dev/null
    if [ $? -eq 1 ]
    then
        echo problem converting $cert to pfx
        exit 1
    fi

    fingerprint=$(openssl x509 -in $cert -noout -fingerprint | cut -d= -f2 | sed 's/://g' )
}

storesecret()
{
    local secretfile=$1
    local name=$2
    filecontentencoded=$( cat $secretfile | base64 $base64_unwrap )

json=$(cat << EOF
{
"data": "${filecontentencoded}",
"dataType" :"pfx",
"password": "${pwd}"
}
EOF
)

    jsonEncoded=$( echo $json | base64 $base64_unwrap )

    r=$(az keyvault secret set --vault-name $vaultname --name $name --value $jsonEncoded)
    if [ $? -eq 1 ]
    then
        echo problem storing secret $name in $vaultname
        exit 1
    fi

    id=$(echo $r | grep -o 'https:\/\/[a-z0-9.]*/secrets\/[a-zA-Z0-9]*/[a-z0-9]*')
    echo Secret ID is $id
}

# We need exactly 7 parameters
if [ "$#" -lt 6 ]; then
    usage
    exit
fi

# The base64 command on OSX does not know about the -w parameter, but outputs unwrapped base64 by default
base64_unwrap="-w 0"
[[ $(uname) == "Darwin" ]] && base64_unwrap=""

vaultname=$1
rgname=$2
location=$3
secretname=$4
cacertfile=$5
keyfile=$6

# Create a random password with 33 bytes of entropy
# I picked 33 so the last character will not be =
pwd=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)

cacertpfxfile=${cacertfile%.*crt}.pfx
casecretname=ca$secretname

createkeyvault

# converting CA cert to pfx
convertcacert $cacertfile $keyfile $cacertpfxfile $pwd
echo $cacertpfxfile fingerprint is $fingerprint
cacertprint=$fingerprint
# storing pfx in key vault
echo Storing $cacertpfxfile as $casecretname
storesecret $cacertpfxfile $casecretname
cacertid=$id
rm -f $cacertpfxfile

# update parameters file
sed -i 's|REPLACE_CACERTURL|'$cacertid'|g' ./azuredeploy.parameters.json
sed -i 's/REPLACE_CACERTPRINT/'$cacertprint'/g' ./azuredeploy.parameters.json
sed -i 's/REPLACE_VAULTNAME/'$vaultname'/g' ./azuredeploy.parameters.json
sed -i 's/REPLACE_VAULTRG/'$rgname'/g' ./azuredeploy.parameters.json

echo Done
