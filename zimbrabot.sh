#!/bin/bash
#Zimbrabot SSL script [v221220]
set -e

<<crontab
30 01 * * *  root    /usr/sbin/zimbrabot
crontab

# VAR
MAINTAINER='it@example.com'

# SYSVAR
HOSTNAME=$(su - zimbra -c "zmcontrol status |grep Host" |cut -d" " -f2)
ZVERSION=$(su - zimbra -c "zmcontrol -v" |cut -d" " -f2 |cut -dG -f1 |cut -d. -f2)
SCRIPT_NAME="$0"
RSN=$(echo "$SCRIPT_NAME" |cut -d'.' -f2 |cut -d'/' -f2)
ARGS="$@"
WDIR='/etc/zimbrabot'
TEMP_DIR='/tmp'
VERSION='221220'
#

if [ ! -d /etc/zimbrabot ]; then
mkdir /etc/zimbrabot
fi

if [ ! -L /etc/zimbrabot/logs ]; then
ln -s /var/log/zimbrabot /etc/zimbrabot/logs
fi

#check_update () {
#if [ "$UCHECK" != "$VERSION" ]; then
#wget example.com/zm/zimbrabot -P "$TEMP_DIR"
#cp "$TEMP_DIR"/"$RSN" "$WDIR"/"$SCRIPT_NAME"
#rm -f "$TEMP_DIR"/"$RSN"
#$SCRIPT_NAME $ARGS
#exit 0
#fi
#}

main () {
{

if [ ! -d /opt/zimbra/ssl/letsencrypt ]; then
mkdir /opt/zimbra/ssl/letsencrypt
chown root.zimbra /opt/zimbra/ssl/letsencrypt
else
chown root.zimbra /opt/zimbra/ssl/letsencrypt
fi

if [ ! -d /var/log/zimbrabot ]; then
mkdir /var/log/zimbrabot
fi

if [ ! -d /etc/letsencrypt/live ]; then
mkdir /etc/letsencrypt/live
fi

if [ ! -L /usr/sbin/zimbrabot ]; then
ln -s /etc/zimbrabot/zimbrabot /usr/sbin/
fi

if [ ! -e /usr/bin/certbot ]; then
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
fi

if [ -d /etc/letsencrypt/live/"$HOSTNAME" ]; then
# SSL existance check
echo 'Checking for existing SSL certificate...'
OLDFILEDATE=$(date -r /etc/letsencrypt/live/"$HOSTNAME"/cert.pem +%d%m%Y)

elif [ ! -d /etc/letsencrypt/live/"$HOSTNAME" ]; then
echo 'No SSL certificate, installing a new one...'
OLDFILEDATE=$'01011970'
fi

# New SSL certificate
if [ ! -d /etc/letsencrypt/live/"$HOSTNAME" ]; then
/usr/bin/certbot certonly -d "$HOSTNAME" -m "$MAINTAINER" --standalone --non-interactive --agree-tos --pre-hook 'su - zimbra -c "zmcontrol stop"'
elif [ -d /etc/letsencrypt/live/"$HOSTNAME" ]; then
# Renewing an existing SSL certificate
/usr/bin/certbot renew --pre-hook 'su - zimbra -c "zmcontrol stop"'
fi

# SSL existance check #2
if [ "$ARGS" = 'force' ]; then
NEWFILEDATE=$'01011970'
else
NEWFILEDATE=$(date -r /etc/letsencrypt/live/"$HOSTNAME"/cert.pem +%d%m%Y)
fi

if [ "$NEWFILEDATE" = "$OLDFILEDATE" ]; then
echo 'SSL Certificate for '"$HOSTNAME"' is not due to renewal on '"$(date)" | tee /var/log/zimbrabot/notyet.log
exit 0

elif [ "$NEWFILEDATE" != "$OLDFILEDATE" ]; then

if [ -e /opt/zimbra/ssl/letesencrypt/chain.pem ]; then
rm /opt/zimbra/ssl/letsencrypt/*
fi
cp /etc/letsencrypt/live/"$HOSTNAME"/* /opt/zimbra/ssl/letsencrypt/
chown -R root.zimbra /opt/zimbra/ssl/letsencrypt/*

# IDENTRUST ROOT INTERMEDIATE CERT
chain2 () {
cat << FINE
-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----
FINE
}

chain2 >> /opt/zimbra/ssl/letsencrypt/chain.pem
cp /etc/letsencrypt/live/"$HOSTNAME"/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown zimbra.zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key

cd /opt/zimbra/ssl/letsencrypt

if [ "$ZVERSION" -le "6" ]; then
echo 'Verifying chain'
/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/chain.pem || true
echo 'Installing chain'
/opt/zimbra/bin/zmcertmgr deploycrt comm /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/chain.pem || true
echo 'Done installing'

elif [ "$ZVERSION" -ge "7" ]; then
echo 'Verifying chain'
su - zimbra -c "/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/chain.pem" || true
echo 'Installing chain'
su - zimbra -c "/opt/zimbra/bin/zmcertmgr deploycrt comm /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/chain.pem" || true
echo 'Done installing'
fi

su - zimbra -c "zmcontrol restart"

echo 'SSL Certificate for '"$HOSTNAME"' has been UPDATED on '"$(date)"' for 90 days' | tee -a /var/log/zimbrabot/renewal.log
fi

} 2>&1 | tee /var/log/zimbrabot/runtime.log
exit 0
}

#check_update # Disabled temporarily
main
