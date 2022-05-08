#!/bin/bash
#Zimbrabot SSL script [v28422]
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
VERSION='28422'
#

if [ ! -d /etc/zimbrabot ]; then
mkdir /etc/zimbrabot
fi

if [ ! -d /var/log/zimbrabot ]; then
mkdir /var/log/zimbrabot
fi


if [ ! -L /etc/zimbrabot/logs ]; then
ln -s /var/log/zimbrabot /etc/zimbrabot/logs
fi

main () {
{

if [ ! -d /opt/zimbra/ssl/letsencrypt ]; then
mkdir /opt/zimbra/ssl/letsencrypt
chown root.zimbra /opt/zimbra/ssl/letsencrypt
else
chown root.zimbra /opt/zimbra/ssl/letsencrypt
fi

if [ ! -d /etc/letsencrypt/live ]; then
mkdir /etc/letsencrypt/live
fi

if [ ! -L /usr/sbin/zimbrabot ]; then
ln -s /etc/zimbrabot/zimbrabot /usr/sbin/
fi

if [ ! -e /usr/bin/certbot ]; then
sudo apt-get install snapd -y #In some ubuntu versions the package is "snapd" not "snap"
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
/usr/bin/certbot certonly -d "$HOSTNAME" -m "$MAINTAINER" --standalone --non-interactive --agree-tos --preferred-chain "ISRG Root X1" --pre-hook 'su - zimbra -c "zmcontrol stop"'
elif [ -d /etc/letsencrypt/live/"$HOSTNAME" ]; then
# Renewing an existing SSL certificate
/usr/bin/certbot renew --preferred-chain "ISRG Root X1" --pre-hook 'su - zimbra -c "zmcontrol stop"'
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
sed '/-----END CERTIFICATE-----/q' /opt/zimbra/ssl/letsencrypt/chain.pem > /opt/zimbra/ssl/letsencrypt/new-chain.pem
chown -R root.zimbra /opt/zimbra/ssl/letsencrypt/*

# ISGR ROOT X1 CROSS CERT
chain2 () {
cat << FINE
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
FINE
}

chain2 >> /opt/zimbra/ssl/letsencrypt/new-chain.pem
cp /etc/letsencrypt/live/"$HOSTNAME"/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown zimbra.zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key

cd /opt/zimbra/ssl/letsencrypt

if [ "$ZVERSION" -le "6" ]; then
echo 'Verifying chain'
/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/new-chain.pem || true
echo 'Installing chain'
/opt/zimbra/bin/zmcertmgr deploycrt comm /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/new-chain.pem || true
echo 'Done installing'

elif [ "$ZVERSION" -ge "7" ]; then
echo 'Verifying chain'
su - zimbra -c "/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/new-chain.pem" || true
echo 'Installing chain'
su - zimbra -c "/opt/zimbra/bin/zmcertmgr deploycrt comm /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/new-chain.pem" || true
echo 'Done installing'
fi

su - zimbra -c "zmcontrol restart"

echo 'SSL Certificate for '"$HOSTNAME"' has been UPDATED on '"$(date)"' for 90 days' | tee -a /var/log/zimbrabot/renewal.log
fi

} 2>&1 | tee /var/log/zimbrabot/runtime.log
exit 0
}

main
