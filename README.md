This script is only for the netbackup master server hosted on a linux machine.
Upload this script to below location or any other location that you prefer:
"/usr/openv/netbackup/hc_auto_script/"

After uploading, give it the privilege for execution:
#chmod u+x /usr/openv/netbackup/hc_auto_script/service_mon.sh

Schedule it to run every 10 minutes via cron:
#crontab -e
Then add below entry:
*/10 * * * * /usr/openv/netbackup/hc_auto_script/service_mon.sh

To see the available cron jobs:
#crontab -l 
-Use the above command to verify that your script has been successfully added to the schedule.

