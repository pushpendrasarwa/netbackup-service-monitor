
#!/bin/bash

# File to log activities
LOG_FILE="/usr/openv/netbackup/hc_auto_script/netbackup_auto_restart.log"
MAX_SIZE=10
DATE_SUFFIX=$(date +"%Y%m%d_%H%M%S")

if [ -f $LOG_FILE ]; then
        FILE_SIZE=$(du -m $LOG_FILE | awk '{print $1}')

        if [ $FILE_SIZE -ge $MAX_SIZE ]; then
                echo "\n $(date):::: Log File Size has reached maximum size. Hence Rotating the Log." >> $LOG_FILE

                ROTATED_LOG = "${LOG_FILE}.${DATE_SUFFIX}"
                mv "$LOG_FILE" "$ROTATED_LOG"

                gzip "$ROTATED_LOG"

                touch "$LOG_FILE"
                echo "$(date):::: New Log File has been created. " >> $LOG_FILE

        else
                echo "$(date):::: File Size Checked and it is within the limit" >> $LOG_FILE

        fi

else
        touch "$LOG_FILE"
                echo "$(date):::: Log File $LOG_FILE not found. Creating a new one"


fi

#List of daemons running on the master server
masters="bpdbm bpjobd nbstserv nbpem nbsvcmon bprd nbim  vnetd nbrmms pbx_exchange bpcd nbsl nbemm NB_dbsrv nbars nbrb nbevtmgr bpcompatd nbaudit nbvault nbjm"

# Get output of bpps -x
echo "$(date):::: Fetching status of the services." >> $LOG_FILE
/usr/openv/netbackup/bin/bpps -x > /usr/openv/netbackup/hc_auto_script/processes

# Flag to indicate restart is needed
restart_needed=false

EMAIL_TO="pushpendra.sarwa.osv@fedex.com"
EMAIL_SUBJECT1="NetBackup Service Alert on $(hostname)"
#EMAIL_SUBJECT2="Auto-Restart Success | NetBackup Service Alert on $(hostname)"
send_alert() {
        local service = $1
        echo -e "Date: $(date) \n\nAlert: NetBackup Services are found to be down on $(hostname)\n #bpps-x: \n$(tail -n 8 "$LOG_FILE")" | mail -s "$EMAIL_SUBJECT1"  "$EMAIL_TO"
}
# Parse output
for master in ${masters}
        do
                count=$(grep -c -w "$master" /usr/openv/netbackup/hc_auto_script/processes)
                if [ "$count" -lt 1 ]
                then
                        echo "$(date): Detected NetBackup service: $master is not running. " >> "$LOG_FILE"
                        restart_needed=true
                        break
                else
                        echo "$(date): Detected NetBackup service: $master is running. " >> "$LOG_FILE"
                        restart_needed=false
                fi
        done

# If any of the critical master process is not running, restart NetBackup
if $restart_needed; then
#    echo "$(date): Detected NetBackup services not running. Affected processes:" >> "$LOG_FILE"
#    for idx in "${!process_names[@]}"; do
#        echo " - ${process_names[$idx]}: ${process_statuses[$idx]}" >> "$LOG_FILE"
#    done

    echo "$(date): Initiating NetBackup service restart..." >> "$LOG_FILE"

    # Step 1: Stop NetBackup services
    /usr/openv/netbackup/bin/goodies/netbackup stop >> "$LOG_FILE" 2>&1

    sleep 5

    # Step 2: Start PBX
    /opt/VRTSpbx/bin/vpbx_exchange start >> "$LOG_FILE" 2>&1

    sleep 5

    # Step 3: Start all NetBackup daemons
    /usr/openv/netbackup/bin/bp.startall >> "$LOG_FILE" 2>&1

     echo "$(date): NetBackup service restart completed." >> "$LOG_FILE"

         send_alert

else
    echo "$(date): All critical NetBackup services are running normally." >> "$LOG_FILE"

fi

