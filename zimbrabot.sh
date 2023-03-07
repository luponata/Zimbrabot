#!/bin/bash
#Zimbrabot SSL script [v7323]
set -e

<<crontab
30 01 * * *  root    /usr/sbin/zimbrabot
crontab

# VAR
MAINTAINER='it@example.com'

# SYSVAR
HOSTNAME=''
#HOSTNAME=$(su - zimbra -c "zmcontrol status |grep Host" |cut -d" " -f2) # You should use manual entry
ZMAJORVERSION=$(su - zimbra -c "zmcontrol -v" |cut -d" " -f2 |cut -dG -f1 |cut -d. -f1)
ZMINORVERSION=$(su - zimbra -c "zmcontrol -v" |cut -d" " -f2 |cut -dG -f1 |cut -d. -f2)
ARGS="$@"
TEMP_DIR='/tmp'
VERSION='7323'
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

if [ ! -L /usr/sbin/zimbrabot ]; then
	ln -s /etc/zimbrabot/zimbrabot /usr/sbin/
fi

if [ ! -e /usr/bin/certbot ]; then
	sudo apt-get install snapd -y #In some ubuntu versions (the newer) the package is "snapd" not "snap"
	sudo snap install core; sudo snap refresh core
	sudo snap install --classic certbot
	sudo ln -s /snap/bin/certbot /usr/bin/certbot
fi

if [ ! -d /etc/letsencrypt/live ]; then
	mkdir -p /etc/letsencrypt
	mkdir /etc/letsencrypt/live
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
	/usr/bin/certbot certonly -d "$HOSTNAME" -m "$MAINTAINER" --standalone --key-type rsa --non-interactive --agree-tos --preferred-chain "ISRG Root X1" --pre-hook 'su - zimbra -c "zmcontrol stop"'
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

# ISRG Root X1 Self-signed
wget https://letsencrypt.org/certs/isrgrootx1.pem -O - >> /opt/zimbra/ssl/letsencrypt/new-chain.pem

cp /etc/letsencrypt/live/"$HOSTNAME"/privkey.pem /opt/zimbra/ssl/letsencrypt/privkey.pem
cp /etc/letsencrypt/live/"$HOSTNAME"/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown zimbra.zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key

cd /opt/zimbra/ssl/letsencrypt

if [ "$ZMAJORVERSION" -le "8" ] && [ "$ZMINORVERSION" -le "6" ]; then
	echo 'Verifying chain'
	/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/new-chain.pem || true
	echo 'Installing chain'
	/opt/zimbra/bin/zmcertmgr deploycrt comm /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/new-chain.pem || true
	echo 'Done installing'
else
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
