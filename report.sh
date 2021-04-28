#!/bin/bash

# Run this script manually or invoke it periodically using cron.
# To do so, add a line like the following with `sudo crontab -e`
#
#    */5 * * * * su user -c /home/user/chia-report-scripts/report.sh
#
# This will execute the script every 5 minutes as user `user`.

# ------------- DEFINE VARIABLES -------------
CWD=$PWD;

API_ENDPOINT="YOUR_HTTP_ENDPOINT"

CHIA_INSTALL_DIR="/home/user/chia-blockchain"
TEMP_DIR="/chia/logs";

CURR_REPORT="${TEMP_DIR}/chia-report-current.log"
PREV_REPORT="${TEMP_DIR}/chia-report-previous.log"
TEMP_REPORT="${TEMP_DIR}/chia-report-temp.log"

# Whitelist the attributes we want from `chia farm summary`
declare -a GET_LINES;
GET_LINES+=("Farming status");
GET_LINES+=("Total chia farmed");
#GET_LINES+=("User transaction fees"); # Commented to reduce noise
#GET_LINES+=("Block rewards"); # Commented to reduce noise
GET_LINES+=("Plot count");
GET_LINES+=("Total size of plots");
#GET_LINES+=("Estimated network space"); # Commented to reduce noise
#GET_LINES+=("Expected time to win"); # Commented to reduce noise

# Build the string payload
TEXT="";

# ----------- END DEFINE VARIABLES ------------

# Check for existing files
if [ -f "$CURR_REPORT" ]; then
    # A current report exists,
    if [ -f "$PREV_REPORT" ]; then
      # A previous report exists; remove it
      rm "$PREV_REPORT";
    fi
    # Replace the previous report with the current report
    mv "$CURR_REPORT" "$PREV_REPORT";
fi

# Activate chia and return to the current directory
cd $CHIA_INSTALL_DIR
. ./activate
cd "$CWD"

# Generate temp report
chia farm summary > "$TEMP_REPORT"

# Find values of interest
while read -r LINE; do
  for EL in "${GET_LINES[@]}"
  do

    if [[ $LINE =~ $EL ]]; then
       VAL=${LINE:$((${#EL} + 2))};
       TEXT="${TEXT}\n${EL}: ${VAL}"
    fi

  done

done < "$TEMP_REPORT"

# Save current report
echo $TEXT > "$CURR_REPORT";

# If there's no previous report, just create an empty file
if [ ! -f "$PREV_REPORT" ]; then
    touch "$PREV_REPORT";
fi

# Compare current and previous reports
if cmp -s "$CURR_REPORT" "$PREV_REPORT"; then
  printf '"%s" is the same as "%s"\n' "$CURR_REPORT" "$PREV_REPORT"
else
  printf '"%s" is different from "%s"\nSEND IT!
' "$CURR_REPORT" "$PREV_REPORT"

  # POST data to Slack
  curl -X POST --data-urlencode "payload={\"text\": \"$TEXT\"}" "$API_ENDPOINT"

fi

# Fin!
exit 0;

