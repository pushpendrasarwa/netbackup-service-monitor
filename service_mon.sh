#!/bin/bash

# File to log activities
LOG_FILE="/usr/openv/netbackup/hc_auto_script/netbackup_auto_restart.log"
MAX_SIZE=10
DATE_SUFFIX=$(date +"%Y%m%d_%H%M%S")

if [ -f $LOG_FILE ]; then
        FILE_SIZE=$(du -m $LOG_FILE | awk '{print $1}')

        if [ $FILE_SIZE -ge $MAX_SIZE ]; then
                echo "\n$(date):::: Log File Size has reached maximum size. Hence Rotating the Log." >> $LOG_FILE

                ROTATED_LOG = "${LOG_FILE}.${DATE_SUFFIX}"
                mv "$LOG_FILE" "$ROTATED_LOG"

                gzip "$ROTATED_LOG"

                touch "$LOG_FILE"
                echo "$(date):::: New Log File has been created. " >> $LOG_FILE

        else
                echo "$(date):::: Log File Size Checked and it is within the limit" >> $LOG_FILE

        fi

else
        touch "$LOG_FILE"
                echo "$(date):::: Log File $LOG_FILE not found. Creating a new one"


fi

#List of daemons running on the master server
#masters="bpdbm bpjobd nbstserv nbpem nbsvcmon bprd nbim  vnetd nbrmms pbx_exchange bpcd nbsl nbemm NB_dbsrv nbars nbrb nbevtmgr bpcompatd nbaudit nbvault nbjm"
masters="nbevtmgr nbstserv vmd bprd bpdbm nbpem nbjm"

# Get output of bpps -x
echo "\n||$(date):::: Fetching status of the services.||" >> $LOG_FILE
$null>/usr/openv/netbackup/hc_auto_script/processes
sleep 1
/usr/openv/netbackup/bin/bpps -x > /usr/openv/netbackup/hc_auto_script/processes

# Flag to indicate restart is needed
restart_needed=false
impacted_service=$null

EMAIL_TO="Accenture-Backup-LAC@corp.ds.fedex.com"
EMAIL_SUBJECT1="NetBackup Service Status on $(hostname)"
#EMAIL_SUBJECT2="Auto-Restart Success | NetBackup Service Status on $(hostname)"
send_alert() {
        local service = $1
        echo -e "Date: $(date) \n\nAlert: NetBackup Service $service found to be down on $(hostname)\n #bpps-x: \n$(tail -n 50 "$LOG_FILE")" | mail -s "$service Found Down | Auto Restarting on Netbackup Server $(hostname)"  "$EMAIL_TO"
}
# Parse output
for master in ${masters}
        do
                count=$(grep -c -w "$master" /usr/openv/netbackup/hc_auto_script/processes)
                if [ "$count" -lt 1 ]
                then
                        echo "$(date): Detected NetBackup service: $master is not running. " >> "$LOG_FILE"
                        restart_needed=true
                        impacted_service=$master
                        #send_alert $master
                        break
                else
                        echo "$(date): NetBackup service: $master is in running state. " >> "$LOG_FILE"
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

    # Step 2: Stop and Start PBX
        /opt/VRTSpbx/bin/vxpbx_exchanged stop >> "$LOG_FILE" 2>&1

        sleep 5

        /opt/VRTSpbx/bin/vxpbx_exchanged start >> "$LOG_FILE" 2>&1

    sleep 5

    # Step 3: Start all NetBackup daemons
    /usr/openv/netbackup/bin/bp.start_all >> "$LOG_FILE" 2>&1

     echo "$(date): NetBackup service restart completed." >> "$LOG_FILE"

         send_alert $impacted_service

else
    echo "$(date): All critical NetBackup services are running normally." >> "$LOG_FILE"
    echo -e "Date: $(date) \nAll NetBackup Services are found to be up and running on $(hostname)\n \n$(tail -n 10 "$LOG_FILE")" | mail -s "$EMAIL_SUBJECT1"  "$EMAIL_TO"

fi
