#!/bin/bash

export STORAGE_ACCESS_ACCOUNT=$1
export STORAGE_ACCESS_KEY=$2
export FQDN=$3
export certprint=$4
export cacerts=$5

sudo docker run -d --name scalityconnect -p 8000:8000 \
-p 8005:8005 -e FQDN=$FQDN \
-e AZURE_STORAGE_ACCESS_KEY=$STORAGE_ACCESS_KEY \
-e AZURE_STORAGE_ACCOUNT=$STORAGE_ACCESS_ACCOUNT \
--log-opt max-size=5g --log-opt max-file=10 \
--restart always scality/connect

# exit on any error
set -eo pipefail

sslcertfilename=$certprint'.crt'
sslkeyfilename=$certprint'.prv'

echo "Copying SSL files"
echo "cert file" $sslcertfilename
fullpath=/var/lib/waagent/$sslcertfilename
if [ -f $fullpath ]
then
    mv $fullpath /etc/ssl/certs/
    echo "Getting CA SSL files"
    wget $cacerts -O 'CASignedCert'$certprint
    chmod 777 /etc/ssl/certs/$sslcertfilename
    cat 'CASignedCert'$certprint >> /etc/ssl/certs/$sslcertfilename
    rm -f 'CASignedCert'$certprint
else
    echo "Cert missing: " $fullpath
    exit 1
fi

echo "private key file" $sslkeyfilename
fullpath=/var/lib/waagent/$sslkeyfilename
if [ -f $fullpath ]
then
    mv $fullpath /etc/ssl/private/
else
    echo "Private Key missing: " $fullpath
    exit 1
fi

echo "creating dhparam"
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

echo "updating main conf file"

sed -i -e 's|\${FQDN}|'"$FQDN"'|g' /etc/nginx/nginx.conf
sed -i 's/${SSL_CERT_FILE_NAME}/'$sslcertfilename'/' /etc/nginx/nginx.conf
sed -i 's/${SSL_KEY_FILE_NAME}/'$sslkeyfilename'/' /etc/nginx/nginx.conf

systemctl restart nginx
