#!/bin/bash

#######################################################
#
# GitHub Enterprise Server (GHES)
# Appliance Debug: ghe-config-apply failure recovery script.
# Author: @appatalks 
# Last update: May 2025
# Compatibility: GHES v3.13 - v.3.16
#
# This script provides multiple troubleshooting levels to restore
# GitHub Enterprise Server functionality when ghe-config-apply fails.
# The run levels include:
#   1. Safe Restarts (fairly safe to attempt)
#   2. Exhaustive Restarts (may require some reconfigurations)
#   3. Destructive Repair (will require rebuilding replicas, possibly data restoration)
#   4. Destructive Start from Scratch (will require data restoration, complete rebuild)
#
# If the basic configuration apply (ghe-config-apply) succeeds (i.e. finds "Done!")
# the script will generate a report and upload the results for support review,
# then exit without making any further changes.
#
#######################################################

# Global variables
TICKET="$1"  # Pass your support ticket variable or pass it as an argument
REPORT_FILE="/tmp/ghes_debug_report.txt"
LOG_FILE="/var/log/ghe_debug.log"
ACTIONS_BACKUP="/home/admin/actions_backup.txt"

###############################
# Utility Functions
###############################

# Function to wait for lockrun process to finish.
wait_for_lockrun() {
  echo "Checking for active lockrun process..."
  while pgrep -f "lockrun --lockfile /var/run/ghe-config.pid" > /dev/null; do
    echo "Waiting for lockrun to finish..."
    sleep 10
  done
}

# Function to enable maintenance mode.
set_maintenance() {
  echo "Enabling maintenance..."
  ghe-maintenance -s
  sleep 60
}

# Function to disable maintenance mode.
unset_maintenance() {
  echo "Disabling maintenance..."
  ghe-maintenance -u
}

# Function to attempt applying configuration and, if successful, generate the report and exit.
try_apply_config() {
  echo "Applying ghe-config-apply... (this may take several minutes, please standby)"
  
  # Run ghe-config-apply in the background
  ghe-config-apply &
  pid=$!
  counter=0
  
  # While the ghe-config-apply process is running, output standby messages.
  while kill -0 "$pid" 2>/dev/null; do
    echo "Configuration in progress... please stand by."
    sleep 20
    counter=$(( counter + 1 ))
  done

  # After ghe-config-apply completes, check for the success message "Done!" in the log.
  if tail -n16 /data/user/common/ghe-config.log | grep -q "Done!"; then
      echo "Configuration applied successfully. All services are running as expected. Unsetting maintenance."
      unset_maintenance
      generate_report
      update_support_ticket
      exit 0
  else
      echo "Configuration did not complete successfully, proceeding with remediation."
  fi
}

# Function to backup Actions configuration variables.
# For when using AWS (S3 - is the better of commercially avail and easy to use platforms imho), so here we are...
backup_actions_config() {
  echo "Backing up Actions configuration variables to ${ACTIONS_BACKUP}..."
  
  # Backup the configuration values to the specified backup file.
  ghe-config secrets.actions.storage.blob-provider > "${ACTIONS_BACKUP}"
  ghe-config secrets.actions.storage.s3.bucket-name >> "${ACTIONS_BACKUP}"
  ghe-config secrets.actions.storage.s3.access-key-id >> "${ACTIONS_BACKUP}"
  ghe-config secrets.actions.storage.s3.access-secret >> "${ACTIONS_BACKUP}"
  ghe-config secrets.actions.storage.s3.service-url >> "${ACTIONS_BACKUP}"
  
  echo "Backup saved to ${ACTIONS_BACKUP}."
  
  # Read the backup file to extract the necessary values.
  # The backup file is expected to contain the following values in order:
  # 1. blob-provider (not needed for restore)
  # 2. bucket-name
  # 3. access-key-id
  # 4. access-secret
  # 5. service-url
  bucket_name=$(sed -n '2p' "${ACTIONS_BACKUP}")
  access_key_id=$(sed -n '3p' "${ACTIONS_BACKUP}")
  access_secret=$(sed -n '4p' "${ACTIONS_BACKUP}")
  service_url=$(sed -n '5p' "${ACTIONS_BACKUP}")
  
  echo ""
  echo "To manually restore these settings later, copy and paste the following command:"
  echo "ghe-actions-precheck -s -o -p s3 -cs \"BucketName=${bucket_name};AccessKeyId=${access_key_id};SecretAccessKey=${access_secret};ServiceUrl=${service_url};PathPrefix=actions-storage-check\";"
  echo "ghe-config app.actions.enabled true; ghe-config-apply"
}

# Function to generate a report of the run.
generate_report() {
  echo "Starting report generation..."
  (
    {
      echo -e "\nServices List:"
      ghe-service-list
      echo -e "\nNomad Node Status:"
      nomad node status -self -verbose
      echo -e "\nNomad Job Status:"
      nomad job status
      echo -e "\nReplication Status:"
      rep_status=$(ghe-cluster-each -s -- ghe-repl-status -v 2>&1)
      echo "$rep_status"
      echo -e "\nghe-spokes status:"
      ghe-spokes status
      echo -e "\nghe-actions-check:"
      ghe-actions-check
      echo -e "\nghe-mssql-console check for database status:"
      ghe-mssql-console -y -q "select name,state_desc,recovery_model_desc from sys.databases"
      echo -e "\nElasticsearch Cluster Health:"
      curl -s "http://localhost:9201/_cluster/health" | jq .status
      echo -e "\nUnassigned shards deletion commands:"
      for i in $(curl -s -XGET 'http://localhost:9200/_cat/shards?h=index,unassigned.reason' | grep "CLUSTER_RECOVERED" | awk '{print $1}' | sort | uniq); do 
        echo "curl --request DELETE http://localhost:9200/$i"
      done
      echo -e "\nActions Configuration Backup (if any):"
      if [ -f "${ACTIONS_BACKUP}" ]; then
        stat "${ACTIONS_BACKUP}"
      else
        echo "No actions backup file found."
      fi
      echo -e "\nLast 25 lines of ghe-config.log:"
      tail -n25 /data/user/common/ghe-config.log
    } > "$REPORT_FILE" 2>&1
  ) &
  pid=$!
  
  count=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$count" -ge 100 ]; then
      echo "Report generation timed out. Please contact Support with your report logs."
      kill "$pid" 2>/dev/null
      break
    elif [ "$count" -ge 60 ]; then
      echo "Okay so the deal is, likely something is turned off, it's okay... some service take a long time to realize."
    elif [ "$count" -ge 40 ]; then
      echo "Please be patient, almost done."
    elif [ "$count" -ge 20 ]; then
      echo "I know this is taking a while. No worries."
    else
      echo "Generating report, Please allow time..."
    fi
    sleep 10
    count=$(( count + 1 ))
  done

  echo "Report generated at $REPORT_FILE"
}

# Function to update the support ticket with the report.
update_support_ticket() {
  if [ -n "$TICKET" ]; then
    echo "Uploading report for support ticket $TICKET..."
    ghe-support-upload -t "$TICKET" -f "$REPORT_FILE"
  else
    echo "No support ticket specified. Skipping upload."
  fi
}

###############################
# Menu and Input Validation
###############################

# Function to print the menu and get the user's choice.
print_menu() {
  echo "#######################################################"
  echo "# GitHub Enterprise Server Debug Menu"
  echo "#######################################################"
  echo "Please select the troubleshooting run level:"
  echo "1. Safe Restarts (fairly safe to attempt)"
  echo "2. Exhaustive Restarts (may require some reconfigurations)"
  echo "3. Destructive Repair (will require rebuilding replicas, possibly data restoration)"
  echo "4. Destructive Start from Scratch (will require data restoration, complete rebuild)"
  echo -n "Enter your choice (1-4): "
  read choice

  if [ "$choice" = "4" ]; then
    echo "ARE YOU SURE? THIS OPTION WILL DESTROY ALL DATA"
    echo "RELOAD THE LICENSE FILE AND SAVE SETTINGS AFTER REBOOT"
    echo -n "Type 'DESTROY DATA' to confirm: "
    read confirm
    if [ "$confirm" != "DESTROY DATA" ]; then
      echo "Confirmation not provided. Aborting Destructive Start from Scratch."
      exit 1
    fi
  fi
}

# Function to validate the user's choice.
validate_choice() {
  case $choice in
    1)
      echo "You selected: SAFE RESTARTS."
      ;;
    2)
      echo "You selected: EXHAUSTIVE RESTARTS."
      ;;
    3)
      echo "You selected: DESTRUCTIVE REPAIR."
      ;;
    4)
      echo "You selected: DESTRUCTIVE START FROM SCRATCH."
      ;;
    *)
      echo "Invalid choice. Please enter a number between 1 and 4."
      return 1
      ;;
  esac
  return 0
}

###############################
# Run Level Functions
###############################

### Option 1: Safe Restarts
safe_restarts() {
  echo "******************************************"
  echo "Running SAFE RESTARTS procedures..."
  echo "******************************************"
  
  wait_for_lockrun
  set_maintenance
  
  # Try applying config. If successful, script exits inside try_apply_config.
  try_apply_config
  
  # If we reach here, configuration did not fully succeed, so proceed with remedial actions.

  # Stop replication
  ghe-repl-stop-all
  
  # Stop alambic.
  sudo nomad stop alambic
  sudo nomad job stop alambic
  
  # Elasticsearch rebalance.
  /usr/local/share/enterprise/ghe-repl-stop-es

  # Nomad 
  sudo nomad stop haproxy-frontend 
  sudo nomad stop haproxy-cluster-proxy 
  sudo nomad stop haproxy-data-proxy
  sudo nomad stop mysql
  sudo nomad stop redis
  sudo nomad stop turboscan
  sudo nomad stop aqueduct-lite
  sudo nomad stop memcached
  sudo nomad stop actions
  sudo nomad stop pages
  sudo nomad stop nginx
  sudo nomad stop gitrpcd
  sudo nomad stop governor
  sudo nomad stop github-timerd
  sudo nomad stop driftwood
  sudo nomad stop hookshot-go
  sudo nomad stop babeld
  sudo nomad stop github-unicorn
  sudo nomad stop github-gitauth
  # others
  sudo service cron stop
  sudo systemctl stop consul
  sudo rm -rf /data/user/consul/raft

  # Run other services
  sudo systemctl restart nomad
  sudo service cron start
  sudo systemctl start consul
  
  # Run Nomad services
  sudo nomad run -hcl1 /etc/nomad-jobs/haproxy/haproxy-frontend.hcl
  sudo nomad run -hcl1 /etc/nomad-jobs/haproxy/haproxy-data-proxy.hcl
  sudo nomad run -hcl1 /etc/nomad-jobs/haproxy/haproxy-cluster-proxy.hcl
  sudo nomad run /etc/nomad-jobs/mysql/mysql.hcl
  sudo nomad run /etc/nomad-jobs/redis/redis.hcl
  sudo nomad run /etc/nomad-jobs/turboscan/turboscan.hcl
  sudo nomad run /etc/nomad-jobs/aqueduct-lite/aqueduct-lite.hcl
  sudo nomad run /etc/nomad-jobs/memcached/memcached.hcl
  # sudo nomad run /etc/nomad-jobs/actions/actions.hcl
  sudo nomad run /etc/nomad-jobs/pages/pages.hcl
  sudo nomad run /etc/nomad-jobs/nginx/nginx.hcl
  sudo nomad run /etc/nomad-jobs/gitrpcd/gitrpcd.hcl
  sudo nomad run /etc/nomad-jobs/governor/governor.hcl
  sudo nomad run /etc/nomad-jobs/github/timerd.hcl
  sudo nomad run /etc/nomad-jobs/driftwood/driftwood.hcl
  # sudo nomad run /etc/nomad-jobs/hookshot-go/hookshot-go.hcl
  # sudo nomad run /etc/nomad-jobs/babeld/babeld.hcl
  sudo nomad run /etc/nomad-jobs/github/unicorn.hcl
  sudo nomad run -hcl1 /etc/nomad-jobs/github/gitauth.hcl

  # Restart alambic.
  sudo nomad run /etc/nomad-jobs/alambic/alambic.hcl

  # Start replication
  ghe-repl-start-all

  ghe-config-apply &
  pid=$!
  counter=0
  
  # While the ghe-config-apply process is running, output standby messages.
  while kill -0 "$pid" 2>/dev/null; do
    echo "Configuration in progress... please stand by."
    sleep 20
    counter=$(( counter + 1 ))
  done
  
  unset_maintenance
}

### Option 2: Exhaustive Restarts
exhaustive_restarts() {
  echo "******************************************"
  echo "Running EXHAUSTIVE RESTARTS procedures..."
  echo "******************************************"
  
  # Execute safe restarts first.
  safe_restarts

  # Check if Actions is enabled
  ACTIONS_ENABLED=$(ghe-config app.actions.enabled)
  if [ "$ACTIONS_ENABLED" != "true" ]; then
    echo "Actions are not enabled. Skipping additional repairs."
    return 0
  fi

  FAILED=0

  # Run additional repairs.
  echo "Running additional repairs..."
  ghe-actions-console -s mps -c Repair-DatabaseLogins || FAILED=1
  ghe-actions-console -s token -c Repair-DatabaseLogins || FAILED=1
  ghe-actions-console -s actions -c Repair-DatabaseLogins || FAILED=1
  ghe-actions-console -s artifactcache -c Repair-DatabaseLogin || FAILED=1
  
  # Compress MSSQL.
  echo "Compressing MSSQL..."
  ghe-export-mssql --compress --stats 1 || FAILED=1
  sudo du --all --human-readable /data/user/mssql/data || FAILED=1
  sudo /usr/local/share/enterprise/ghe-mssql-shrinkfile --disable-mssql-replication --set-simple-recovery-model || FAILED=1
  sudo du --all --human-readable /data/user/mssql/data || FAILED=1
  
  # Restart MSSQL.
  if [ -f "/etc/github/cluster" ]; then
    echo "Cluster configuration detected. Restarting MSSQL in cluster mode..."
    ghe-cluster-each --serial --replica --role mssql -- sudo /usr/local/share/enterprise/ghe-repl-start-mssql || FAILED=1
    # Run ghe-actions-check and ignore specific error messages.
    ghe-actions-check || echo "Ignoring MSSQL not healthy error"
  else
    echo "No clustering detected. Restarting MSSQL in standalone mode..."
    cd /tmp
    . /usr/local/share/enterprise/ghe-mssql-lib
    set +e
    restart-mssql-global || FAILED=1
    ghe-actions-check || echo "Ignoring MSSQL not healthy error"
  fi

  # If any step failed in the additional repair steps, disable Actions.
  if [ $FAILED -ne 0 ]; then
      echo "One or more additional repair steps failed. Disabling Actions..."
      backup_actions_config
      ghe-config app.actions.enabled false
      ghe-config-apply
  else
      echo "Additional repairs succeeded."
  fi
}

### Option 3: Destructive Repair (Including Safe and Exhaustive Restarts)
destructive_repair() {
  echo "******************************************"
  echo "Running DESTRUCTIVE REPAIR procedures..."
  echo "******************************************"
  
  # Execute previous repair levels. (maybe we can skip this.)
  # exhaustive_restarts

  # Backup Actions config and disable
  backup_actions_config
  ghe-config app.actions.enabled false

  # Additional destructive repair actions.
  /usr/local/share/enterprise/ghe-nomad-local-alloc-stop elasticsearch
  sudo rm -rf /data/user/elasticsearch/_state
  sudo rm -f /etc/github/repl-{state,remote,running} /data/user/common/cluster.conf /etc/github/cluster
  ghe-single-config-apply
  ghe-mssql-console -y -q "DROP AVAILABILITY GROUP [ha]"
  sudo nomad stop mssql
  sudo nomad run /etc/nomad-jobs/mssql/mssql.hcl
  ghe-single-config-apply
}

### Option 4: Destructive Start from Scratch
destructive_start() {
  echo "******************************************"
  echo "Running DESTRUCTIVE START FROM SCRATCH procedures..."
  echo "******************************************"
  
  # Execute destructive base install steps.
  sudo systemctl stop fluent-bit
  sudo systemctl stop ghe-user-disk
  sudo systemctl stop ghe-user-disk.path
  
  # Attempt to unmount /data/user; if it fails, recommend reboot.
  sudo umount /data/user
  if [ $? -ne 0 ]; then
    echo "Error: Unmounting /data/user failed. Please reboot the appliance and try again."
    exit 1
  fi

  sudo rm -f /etc/github/repl-{state,remote,running} /data/user/common/cluster.conf /etc/github/cluster
  sudo dd if=/dev/zero of=$(sudo pvs --noheadings -o pv_name | tr -d ' ') bs=512 count=10000 conv=notrunc
  sudo dmsetup remove_all
  sudo /usr/local/share/enterprise/ghe-storage-init
  sleep 10
  ghe-maintenance -u
  # Echo next steps and give the user time before initiating a reboot.
  echo "____"
  echo "____"
  echo "Next steps: After the appliance reboots, if you see the Unicorn page, please manually start unicorn with (and then wait 10 minutes):"
  echo "  sudo nomad run /etc/nomad-jobs/github/unicorn.hcl 2>&1 &"
  sleep 10
  sudo shutdown -r now
}

###############################
# Main Script Execution
###############################
while true; do
  print_menu
  validate_choice && break
done

# Execute the selected troubleshooting run level.
case $choice in
  1)
    safe_restarts
    ;;
  2)
    exhaustive_restarts
    ;;
  3)
    destructive_repair
    ;;
  4)
    destructive_start
    ;;
esac

###############################
# Final Checks and Reporting (if not already exited earlier)
###############################
echo "******************************************"
echo "Running final status checks and generating report..."
echo "******************************************"

generate_report
update_support_ticket

echo "Script execution completed. Please review the report at $REPORT_FILE for details."


##### Scratch Thoughts

#### review this for later implimentation.
## Enable Actions
# ghe-config app.actions.enabled true
# ghe-config-apply

# cluster commands
#ghe-cluster-each -xs -- sudo systemctl restart nomad
#ghe-cluster-each -xs -- sudo systemctl restart nomad-jobs
#ghe-cluster-each -xs -- sudo systemctl restart nomad-jobs.timer
#   -x | --exclude                Exclude local host
#   -s | --serial                 Run commands serially.

# ghe-config-apply fails with databases due to inprogress-stuck recovery.
# ghe-mssql-console -y -q "select name,state_desc,recovery_model_desc from sys.databases"
# ghe-mssql-console -y -n -q "RESTORE DATABASE [Mps_Configuration] WITH RECOVERY"
# ghe-mssql-console -y -n -q "RESTORE DATABASE [Token_Configuration] WITH RECOVERY
# ghe-mssql-console -y -n -q "RESTORE DATABASE [Pipelines_Configuration] WITH RECOVERY"
# ghe-mssql-console -y -n -q "RESTORE DATABASE [ArtifactCache_Configuration] WITH RECOVERY"


### Unsorted nomad services review
# viewscreen, notebooks, lfs-server, gpgverify, github-ernicorn, codeload, babeld2hydro, frontend, backend, frontend, treelights, 
# token-scanning-udp-backfill-worker, token-scanning-scans-api, token-scanning-reposync-worker, token-scanning-partner-validity-check-worker
# token-scanning-jobgroup-worker, token-scanning-incremental-worker, token-scanning-hydro-consumer, token-scanning-hcs-upgrade-backfill-worker, token-scanning-content-scan-worker
# token-scanning-content-backfill-worker, token-scanning-backfill-worker, token-scanning-api, spokes-sweeper, spokesd, mail-replies, grafana, github-stream-processors 
# github-resqued, alive, authzd, authnd, kredz-varz, kredz-hydro-consumer, kredz, minio, kafka-lite, http2hydro, graphite-web, git-daemon, github-env, consul-template
