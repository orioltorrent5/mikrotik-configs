#!/bin/bash
# Script to automate backups for Mikrotiks

config_mikrotik='/home/indaleccius/backup_mikrotiks/info_mikrotik_test.csv' # Files wiht mikrotik information
MTBACKUPDIR='/example/backups' # Local directory where save backup files
DATA=$(date +%Y-%m-%d)
sshlog="/var/log/mikrotik/mikrotickSSHlog_$DATA.log"
CORREU="/var/log/mikrotik/mikrotiksbck_$DATA.log" # Save content of the mail
sendmail="example@mail.com example@mail.com"
regexdyn='^[a-zA-Z0-9]{12}\.sn\.mynetname\.net$'	# mikrotik dyn dns
regexip='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' # check if ip is valid
zipfile="/example/BackupMikrotik.zip" # Path of the zip file
OK=0
ERR=0
TOTAL=0

# Read config file line by line
first_line=true;
count_line=0;

if [ -f "$CORREU" ];then
        rm "$CORREU"
fi

echo "BACKUPS MIKROTIK USERS - $(date)" >> $CORREU
echo "" >> $CORREU

while IFS= read -r line;
do
	status="OK"
	count_line=$((count_line + 1));
	if $first_line; then
		first_line=false
	else
		# Verfication if the line is not a comment.
		if [[ $(echo $line | cut -c 1) != "#" ]];then

			#Save the info of line.
			group=$(echo $line | awk -F "," '{print $1}')
			ip=$(echo $line | awk -F "," '{print $2}')
			user=$(echo $line | awk -F "," '{print $3}')
			passwd=$(echo $line | awk -F "," '{print $5}')
			client=$(echo $line | awk -F "," '{print $4}')
			port=$(echo $line | awk -F "," '{print $6}' | sed 's/[^0-9]//g')
			noping=$(echo $line | awk -F "," '{print $7}')
			client_not_space=$(echo $line | awk -F "," '{print $4}' | sed 's/ //g')
			echo "$ip"
			echo "$group"
			echo "$client"
			echo "$user"
			echo "$passwd"
			echo "$port"
			echo "$noping"
			# Detect errors of the file and alert in the mail
			if [ -z "$client" ];then
				echo "Line $count_line is NOT well done (Client: $client/IP: $ip/Port: $port) - Error in client: $client" >> $CORREU
				continue;
			fi

			if [ -z $ip ]; then
				echo "Line $count_line is NOT well done (Client: $client/IP: $ip/Port: $port) - Error in ip: $ip" >> $CORREU
				continue;
			fi

			if ! [[ $ip =~ $regexip || $ip =~ $regexdyn ]]; then
				echo "Line $count_line is NOT well done (Client: $client/IP: $ip/Port: $port) - Error in ip: $ip" >> $CORREU
				continue;
			fi

			if [ -z $passwd ];then
				echo "Line $count_line is NOT well done (Client: $client/IP: $ip/Port: $port) - Error in passwd: $passwd" >> $CORREU
				continue;
			fi

			if ! [[ $port =~ ^[0-9]{1,5}$ || -z $port ]]; then
				echo "Line $count_line is NOT well done (Client: $client/IP: $ip/Port: $port) - Error in port: $port" >> $CORREU
				continue;
			fi

			# Create subdirectory for device if the direcotry doesn't exist.
			if ! [ -d $MTBACKUPDIR/$client_not_space ];then
				echo "Directory $MTBACKUPDIR/$client_not_space doesn't exist"  # DEBUG
				mkdir $MTBACKUPDIR/$client_not_space
			fi

			# Check if the host respons icmp request.
			cmd='ping -c 3 '"$ip"

			# Get loss % result of the ping command
			loss=$($cmd | grep "loss" | cut -d "," -f3 | cut -d " " -f2)

			# if not realize pings becouse is block then check this otpion
			if [ -z "$noping" ];then
				noping=""
			else
				noping="noping"
			fi

			# In case of the port is null, then don't use any port. Command ssh use default port 22.
			if [ -z "$port" ];then
				port=""
				port_scp=""
			else
				port_scp=$(echo -P $port)
				port=$(echo -p $port)
			fi

			if [[ "$loss" == '0%' || "$noping" == "noping" ]]; then

				echo "Realitzant backup: $client"
				# .RSC Backup
				sshpass -p $passwd ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $port $user@$ip export file=backupfile < /dev/null > $sshlog
                		sleep 3
				if [ $? -ne 0 ]; then
        				echo "Failed to create RSC backup for $client" >> "$sshlog"
        				status="ERROR"
    				fi

                		# .BACKUP File
                		sshpass -p $passwd ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $port $user@$ip system backup save name=backupfile < /dev/null > $sshlog
                		sleep 3
	                        if [ $? -ne 0 ]; then
                                        echo "Failed to create system backup for $client" >> "$sshlog"
                                        status="ERROR"
                                fi


                		# Transfer files on local machine with scp.
                		sshpass -p $passwd scp $port_scp $user@$ip:/backupfile.rsc $MTBACKUPDIR/$client_not_space/ < /dev/null > $sshlog
				if [ $? -ne 0 ]; then
        				echo "Failed to transfer RSC file for $client" >> "$sshlog"
        				status="ERROR"
    				fi

               	 		sshpass -p $passwd scp $port_scp $user@$ip:/backupfile.backup $MTBACKUPDIR/$client_not_space/ < /dev/null > $sshlog
				if [ $? -ne 0 ]; then
        				echo "Failed to transfer backup file for $client" >> "$sshlog"
        				status="ERROR"
    				fi

                		# Delete files of Mikrotik.
                		sshpass -p $passwd ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $port $user@$ip rm backupfile.rsc backupfile.backup < /dev/null > $sshlog

				if [ $? -ne 0 ]; then
					echo "Failed to delete backup files on Mikrotik for $client" >> "$sshlog"
					status="ERROR"
				fi

				if [ $status == 'OK' ]; then
					echo -e "$TOTAL- $client --> OK" >> "$CORREU"
					OK=$(($OK+1))
				else
					echo -e "$TOTAL- $client --> ERROR" >> "$CORREU"
					ERR=$(($ERR+1))
				fi
				TOTAL=$(($TOTAL+1))

			else
				echo -e "$client ERROR => Is not possible carry out ping to $ip"
				echo -e "Group is => $group (No Acces is normal no ping)"
				echo -e "$TOTAL- $client --> ERROR" >> "$CORREU"
				ERR=$(($ERR+1))
				TOTAL=$(($TOTAL+1))
			fi
			echo "--------------------------------"
		fi
	fi
	echo "Finished processing line $count_line"  # Afegir missatge de depuració
done < "$config_mikrotik"

# Create ZIP for send in mail.
zip -r $zipfile $MTBACKUPDIR/*
echo "ZIP created"

# Send the mail
echo "" >> $CORREU
echo "" >> $CORREU
echo "BACKUPS FINISHED - $(date)" >> $CORREU

SUBJECT="Backups Mikrotiks $DATA || Errors: $ERR Successfully: $OK Total: $TOTAL"

# Send the mail using mailx with without HTML
# TODO: Include html conent attach file and change content type is not compatible with mailx.
cat $CORREU | mail -r "example@example.com" -A $zipfile -s "$SUBJECT" $sendmail
