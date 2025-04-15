CURRENT_IP=$(curl -s ipv4.icanhazip.com)
PREVIOUS_IP=""

FAIL2BAN_IGNOREIP="/etc/fail2ban/jail.local"
APACHE_CONF="/etc/apache2/apache2.conf"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

clear
echo -e " This script curls icanhazip.com to get the current Public IP address.\n\t(Pinging self (domain) or a DNS server is also possible,\n\tbut this should work whether there is a domain registered or not.)"
echo -e " It then copies the IP in apache.conf for whitelisting on mod_evasive and other modules,"
echo -e " In the ignoreip field of the jail.local configuration file of Fail2Ban,"
echo -e " And within the OSSEC configuration file under <global>."
printf '%.s─' $(seq 1 $(tput cols))
echo -e "\n"

# GET PREVIOUS IP ####################################################################################################

previous_ip_line=$(grep "^Define CURRENT_IP .*" "$APACHE_CONF")
PREVIOUS_IP=$(echo ""$previous_ip_line"" | awk '{print $3}')
echo -e " (!) Previous IP was: "$PREVIOUS_IP"\n"

# APACHE2 ############################################################################################################

echo " ... Searching for pre-existing configurations in Apache2"
if grep -q "^Define CURRENT_IP " "$APACHE_CONF"; then
    sed -i "s|^Define CURRENT_IP .*|Define CURRENT_IP $CURRENT_IP|" "$APACHE_CONF"
    echo " (1) Tried updating Define CURRENT_IP to \"$CURRENT_IP\" in $APACHE_CONF."
else
    # Insert the variable if it doesn't exist BEFORE the loading of other modules. (so that they are aware of CURRENT_IP)
    #sed -r '/^(# Include module configuration:|IncludeOptional mods-enabled\/\*\.load)/i Define CURRENT_IP '"$CURRENT_IP" "$APACHE_CONF"
    sed -i -r "/^(# Include module configuration:|IncludeOptional mods-enabled\/\*\.load)/ {
    i Define CURRENT_IP $CURRENT_IP
    :a
    n
    \$!ba
    }" "$APACHE_CONF"
    # The previous mumbo-jumbo sets a loop that consumes next line and if it is not the last one, loops again till the end.
    # avoids truncation and multiple inserts.
    echo " (1) Tried inserting Define CURRENT_IP \"$CURRENT_IP\" to $APACHE_CONF."
    echo " /!\ Please ensure that the CURRENT_IP is set before the loading of modules in the apache conf file."
fi

echo -e " (!) Reloading Apache2...\n"
sudo systemctl reload apache2

# FAIL2BAN ###########################################################################################################

echo " ... Searching for pre-existing configuration in Fail2Ban..."
if grep -q "^ignoreip = 127.0.0.0/8 ::1 192.168.1.0/24 0.0.0.0.*" "$FAIL2BAN_IGNOREIP"; then
    sed -i "s|^ignoreip = 127.0.0.0/8 ::1 192.168.1.0/24 0.0.0.0.*|ignoreip = 127.0.0.0/8 ::1 192.168.1.0/24 0.0.0.0 $CURRENT_IP|" "$FAIL2BAN_IGNOREIP"
    echo " (2) Tried updating ignoreip to contain: \"$CURRENT_IP\" in $FAIL2BAN_IGNOREIP"
else
    # Simply append the variable if it doesn't exist
    echo "ignoreip = 127.0.0.0/8 ::1 192.168.1.0/24 0.0.0.0 $CURRENT_IP" >> "$FAIL2BAN_IGNOREIP"
    echo " (2) Tried adding ignoreip containing \"$CURRENT_IP\" to $FAIL2BAN_IGNOREIP"
fi

echo -e " (!) Reloading fail2ban..."
sudo fail2ban-client reload

# UNBAN FROM F2B (TODO: MAKE IT BETTER) #############################################################################

echo " (!) Trying to unban current IP from fail2ban jails, just in case."
sudo fail2ban-client set modsec unbanip $CURRENT_IP
sudo fail2ban-client set apache-modsecurity unbanip $CURRENT_IP
sudo fail2ban-client set snort unbanip $CURRENT_IP
sudo fail2ban-client set nextcloud unbanip $CURRENT_IP
sudo fail2ban-client set gitea unbanip $CURRENT_IP
echo -e "\n"

# OSSEC ############################################################################################################

echo " ... Searching for pre-existing configuration in OSSEC..."
# OLD
# check for non-lan non-lo IPs
# if grep -Pzo '<white_list>((?!127\.0\.0\.1|::1|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2[0-9]|3[0-1])\.\d+\.\d+).)*</white_list>' "$OSSEC_CONF"; then

# OR IF PREVIOUS IP IS "".
if grep -q "<white_list>"$PREVIOUS_IP"</white_list>" "$OSSEC_CONF"; then
    sed -i "s|^<white_list>"$PREVIOUS_IP"</white_list>$|<white_list>"$CURRENT_IP"</white_list>|" "$OSSEC_CONF"
    echo " (3) Tried updating tag white_list for IP to \"$CURRENT_IP\" in $OSSEC_CONF."
else
   sed -i "/<global>/{a\
	<white_list>$CURRENT_IP</white_list>
	:a
	n
	\$!ba
	}" $OSSEC_CONF
   echo " (3) Tried inserting tag: white_list for IP: \"$CURRENT_IP\" within $OSSEC_CONF."
fi

echo -e " (!) Restarting OSSEC..."
sudo systemctl restart ossec
