Use with caution, make sure file is owned by root and has a chmod of 700 unless you know what you're doing

This ONLY works with the cloudflare DNS method

DIR: specifies what directore this program should be run in, useful when being run from cron or another directory
ALGO: algorithm to pass to openssl
NAME: domain name for certificate
CLOUDFLARE_EMAIL: email address used for cloudfloare
CLOUDFLARE_KEY: API key for cloudlare
  The api key must have edit access to the domain 
 
It's best to test with debug set to 1 until you are sure this works.

You must install certbot either using your package manager or pip

It can be installed with:
 `apt install certbot`

The cloudflare dns extension can be installed with:
 `pip install certbot-dns-cloudflare`
