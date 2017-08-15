#!/bin/bash
## Create self-signed certs
## 
## Must be ran on host which has keytool installed (eg bastion) 
##
## Args: 
##  project_name	${PROJECTNAME}		- project to deploy SSO into
##  keystore_password	${KSPASSWORD}		- the passwords set on all three keystores and certs (sso-https.jks truststore.jks jgroups.jceks)
##  ca_password		${CAPASSWORD}		- the password set on the self-signed CA "ca.key/ca.crt" which is created 

# Parse command-line options
if [ "$#" -ne 3 ]; then
	echo "${0} - Creates self-signed keystores suitable for RH SSO"
    	echo "You must enter exactly 3 command line arguments"
	echo ""
	echo "Usage:"
	echo "${0} <project_name> <keystore_password> <ca_password>"
	echo ""
	echo "Args: 
project_name        - project to deploy SSO into
keystore_password   - the passwords set on all three keystores and certs (sso-https.jks truststore.jks jgroups.jceks)
ca_password         - the password set on the self-signed CA "ca.key/ca.crt" which is created "
	exit 1
fi

PROJECTNAME=$1
KSPASSWORD=$2
CAPASSWORD=$3

# Constants
WORKINGDIR=`pwd`/${PROJECTNAME}
mkdir ${WORKINGDIR}
cd ${WORKINGDIR}

## Create keystore files
openssl req -new -newkey rsa:4096 -x509 -passin pass:${CAPASSWORD} -passout pass:${CAPASSWORD} -keyout ca.key -out ca.crt -days 365 -subj "/CN=ca-sso"
keytool -genkeypair -keyalg RSA -keysize 2048 -dname "CN=sso" -alias sso-https-key -storepass ${KSPASSWORD} -keypass ${KSPASSWORD} -keystore sso-https.jks
keytool -certreq -keyalg rsa -alias sso-https-key -storepass ${KSPASSWORD} -keystore sso-https.jks -file sso.csr
openssl x509 -req -passin pass:${CAPASSWORD} -CA ca.crt -CAkey ca.key -in sso.csr -out sso.crt -days 365 -CAcreateserial
keytool -import -file ca.crt -alias ca.crt -storepass ${KSPASSWORD} -trustcacerts -noprompt -keystore sso-https.jks
keytool -import -file sso.crt -alias sso-https-key -storepass ${KSPASSWORD} -keystore sso-https.jks

keytool -import -storepass ${KSPASSWORD} -file ca.crt -alias ca.crt -trustcacerts -noprompt -keystore truststore.jks
keytool -genseckey -storepass ${KSPASSWORD} -keypass ${KSPASSWORD} -alias jgroups -storetype JCEKS -keystore jgroups.jceks


for file in "${WORKINGDIR}/sso-https.jks ${WORKINGDIR}/truststore.jks ${WORKINGDIR}/jgroups.jceks"
do
    if [ -e "$file" ]
    then echo "$file is missing - check for errors in keystore creation above" >&2; exit 0
    fi
done
echo ""
echo "####################################################################"
echo "Self-signed Keystore Files created in ${WORKINGDIR}:"
echo "sso-https.jks - Keystore containing HTTPS cert 'sso-https-key'"
echo "truststore.jks - Keystore contining self-signed CA cert"
echo "jgroups.jceks - Keystore containing jgroups security key 'jgroups'"
echo ""
echo "Password for ca.key is ${CAPASSWORD}"
echo "Keystore password is ${KSPASSWORD}"
