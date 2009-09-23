expect <<-HERE | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/vhz.pem
spawn openssl s_client -connect mail.vloerhoutzwolle.nl:993 
expect "* OK Dovecot DA ready."
send "Q\n"
HERE

expect <<-HERE | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/pcextreme.pem
spawn openssl s_client -connect pcextreme.nl:443
expect -exact "-----END CERTIFICATE-----"
send "Q\n"
HERE

expect <<-HERE | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/pcextreme-mail.pem
spawn openssl s_client -connect mail.pcextreme.nl:993
expect -exact "-----END CERTIFICATE-----"
send "Q\n"
HERE

expect <<-HERE | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/hwm.pem
spawn openssl s_client -connect mail.handwerkmassages.org:993
expect -exact "-----END CERTIFICATE-----"
send "Q\n"
HERE

expect <<-HERE | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/mpe.pem
spawn openssl s_client -connect mail.dotmpe.com:443
expect -exact "-----END CERTIFICATE-----"
send "Q\n"
HERE

# Searching for 'local issuer certificate'
# the cert signer for *.pcextreme.nl?
#
expect <<-HERE | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/rapidssl.pem
spawn openssl s_client -connect www.rapidssl.com:443
expect -exact "-----END CERTIFICATE-----"
send "Q\n"
HERE

c_rehash ~/.certs/
