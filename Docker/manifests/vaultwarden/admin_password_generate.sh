cat admin_password | xargs echo -n | argon2 "$(openssl rand -base64 32)" -e -id -k 19456 -t 2 -p 1 > ./secrets/admin_token
