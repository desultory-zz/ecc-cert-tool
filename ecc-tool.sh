#!/bin/bash
#Set to 1 to increase verbosity and use staging server
#You should keep this set to 1 until you know it works and set to 0 when ready to deploy
DEBUG=1
#Set to the dir it runs in, important for using cron
DIR="/CHANGE/THIS/DIR"
#ECC type
ALGO="secp384r1"
#Domain name
NAME="EXAMPLE.COM"
#Cloudflare email address
CLOUDFLARE_EMAIL="ADMIN@EXAMPLE.COM"
#Cloudflare api key
CLOUDFLARE_KEY="EXAMPLE_CLOUDFLARE_API_KEY"

#Create cloudflare.ini file with chmod 600
function generate_cloudflare_conf() {
	echo "dns_cloudflare_email = $CLOUDFLARE_EMAIL" > $DIR/cloudflare.ini
	echo "dns_cloudflare_api_key = $CLOUDFLARE_KEY" >> $DIR/cloudflare.ini
	chmod 600 $DIR/cloudflare.ini

	if [[ "$DEBUG" == 1 ]]; then
		echo "Wrote cloudflare.ini with values: "
		cat $DIR/cloudflare.ini
	fi
}

#Create openssl conf with chmod 600
function generate_openssl_conf() {
	echo "[ req ]" > $DIR/openssl.conf
	echo "prompt = no" >> $DIR/openssl.conf
	echo "encrypt_key = no" >> $DIR/openssl.conf
	echo "default_md = sha512" >> $DIR/openssl.conf
	echo "distinguished_name = dname" >> $DIR/openssl.conf
	echo "req_extensions = reqext" >> $DIR/openssl.conf
	echo "[ dname ]" >> $DIR/openssl.conf
	echo "CN = $NAME" >> $DIR/openssl.conf
	echo "emailAddress = example@example.com" >> $DIR/openssl.conf
	echo "[ reqext ]" >> $DIR/openssl.conf
	echo "subjectAltName = DNS:$NAME, DNS:*.$NAME" >> $DIR/openssl.conf
	chmod 600 $DIR/openssl.conf

	if [[ "$DEBUG" == 1 ]]; then
		echo "Wrote openssl.conf with values: "
		cat $DIR/openssl.conf
	fi
}

#Move old certs
function move_old_certs() {
	mkdir $DIR/old
	if [ -f $DIR/$NAME-cert.pem ]; then
		mv $DIR/$NAME-cert.pem $DIR/old
	fi
	if [ -f $DIR/$NAME-chain.pem ]; then
		mv $DIR/$NAME-chain.pem $DIR/old
	fi
	if [ -f $DIR/$NAME-fullchain.pem ]; then
		mv $DIR/$NAME-fullchain.pem $DIR/old
	fi
	if [ -f $DIR/$NAME-privkey.pem ]; then
		mv $DIR/$NAME-privkey.pem $DIR/old
	fi
}

#Generate new keys and CSR
function generate_csr() {
	#generate new private key
	openssl ecparam -genkey -name $ALGO -out $DIR/$NAME-privkey.pem
	#generate request
	openssl req -new -config $DIR/openssl.conf -key $DIR/$NAME-privkey.pem -out $DIR/$NAME-csr.pem

	if [[ "$DEBUG" == 1 ]]; then
		echo "CSR Contents: "
		openssl req -in $DIR/$NAME-csr.pem -noout -text
	fi
}

#Sends CSR and obtains new certs
function send_csr() {
	if [[ "$DEBUG" == 1 ]]; then
		certbot certonly --agree-tos --register-unsafely-without-email \
			--dns-cloudflare --dns-cloudflare-credentials \
			$DIR/cloudflare.ini --csr $DIR/$NAME-csr.pem \
			--cert-name $NAME --cert-path $DIR/$NAME-cert.pem --staging
	else
		certbot certonly --quiet --non-interactive --agree-tos --register-unsafely-without-email \
			--dns-cloudflare --dns-cloudflare-credentials \
			$DIR/cloudflare.ini --csr $DIR/$NAME-csr.pem \
			--cert-name $NAME --cert-path $DIR/$NAME-cert.pem
	fi
}

#Resets if failure was detected
function revert() {
	echo "Deleting openssl and cloudflare configuration"
	rm $DIR/openssl.conf
	rm $DIR/cloudflare.ini
	echo "Deleting CSR and private key"
	rm $DIR/$NAME-csr.pem
	rm $DIR/$NAME-privkey.pem
	if [ -f $DIR/old/$NAME-cert.pem ]; then
		echo "Restoring old certificate"
		mv $DIR/old/$NAME-cert.pem $DIR
	else
		echo "ERROR: OLD CERTIFICATE NOT FOUND"
	fi
	if [ -f $DIR/old/$NAME-chain.pem ]; then
		echo "Restoring old chain"
		mv $DIR/old/$NAME-chain.pem $DIR
	else
		echo "ERROR: OLD CHAIN NOT FOUND"
	fi
	if [ -f $DIR/old/$NAME-fullchain.pem ]; then
		echo "Restoring old fullchain"
		mv $DIR/old/$NAME-fullchain.pem $DIR
	else
		echo "ERROR: OLD FULLCHAIN NOT FOUND"
	fi
	if [ -f $DIR/old/$NAME-privkey.pem ]; then
		echo "Restoring old privkey"
		mv $DIR/old/$NAME-privkey.pem $DIR
	else
		echo "ERROR: OLD PRIVKEY NOT FOUND"
	fi
	rmdir $DIR/old
}

#Revokes old certs
function revoke_certs() {
	if [ ! -f $DIR/$NAME-cert.pem ]; then
		echo "Failure detected, moving old certs back if they exist"
		revert
		exit
	fi

	if [[ "$DEBUG" == 1 ]]; then
		echo "Revoking old cert at $DIR/old/$NAME-cert.pem"
		#Don't delete after revoke because script will delete it
		if [ -f $DIR/old/$NAME-cert.pem ]; then
			certbot revoke --staging --cert-path $DIR/old/$NAME-cert.pem --no-delete-after-revoke
		fi
	else
		#Don't delete after revoke because script will delete it
		if [ -f $DIR/old/$NAME-cert.pem ]; then
			certbot revoke --cert-path $DIR/old/$NAME-cert.pem --no-delete-after-revoke
		fi
	fi
}

#Cleans up files
function clean_run() {
	rm $DIR/old/ -r
	rm $DIR/openssl.conf
	rm $DIR/cloudflare.ini
	rm $DIR/$NAME-csr.pem
	mv $DIR/0000_chain.pem $DIR/$NAME-chain.pem
	mv $DIR/0001_chain.pem $DIR/$NAME-fullchain.pem
}

#Reloads webserver
function reload_webserver() {
	if [[ "$DEBUG" == 1 ]]; then
		echo "Not reloading webserver since certs generated are staging certs"
	else
		systemctl reload apache2
	fi
}


#RUN
cd $DIR
generate_cloudflare_conf
generate_openssl_conf
move_old_certs
generate_csr
send_csr
revoke_certs
clean_run
reload_webserver
