#!/bin/bash
echo "--------------TEST RUN---------------"
DB_user=$(grep DB_user /run/secrets/secret | awk -F "=" '{print $2}')
DB_password=$(grep DB_password /run/secrets/secret | awk -F "=" '{print $2}')
DB_endpoint=$(grep DB_endpoint /run/secrets/secret | awk -F "=" '{print $2}')
echo ""
echo "DB endpoint is $DB_endpoint"
echo "DB user name is $DB_user"
echo "DB password is $DB_password"
echo ""
echo "------------END TEST RUN-------------"
