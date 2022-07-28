#!/bin/bash

# Intro and read installs variable
printf "\r\n"
printf '\e[1;34m%-6s\e[m' "WP Engine Factfind 2"
printf "\r\n"
echo "NOTE: This will ONLY work with WP Engine Production Pods and Servers."
echo "Enter Install Names using Space as a Separator:"

read installsinit

# Declare Global Vars
installs="$installsinit"; 
installdisk=0; 
errortotal=0; 
dbtotal=$(echo 0.0 | bc);
initialdir=$(echo $PWD);
all=$(zcat -f /var/log/apache2/*.access.log* | wc -l); 
totbsph=$(zcat -f /var/log/nginx/*.access.log.* | awk -F '|' '{sum += $9} END {print substr((sum/7)/3600,0,6)}'); 
cid=$(hostname | cut -d'-' -f2); count=$(($(ls -l /nas/content/live/ | wc -l | bc)-1));
az=$(wpephp server-option-get $cid | grep "availability_zone" | cut -d'>' -f2); 
machine=$(wpephp server-option-get $cid | grep "machine_type" | cut -d'>' -f2); 
plan=$(wpephp server-option-get $cid | grep "sales_offering" | cut -d'>' -f2); 

dedi=$(wpephp server-option-get $cid | grep "single-tenant\|multi-tenant"); 
if [[ $dedi =~ "single" ]]; 
    then 
        dediout="Premium"; 
    else 
        dediout="Shared"; 
fi; 

evlvfind=$(wpephp server-option-get $cid | grep "ansible_groups"); 
if [[ $evlvfind =~ "evlv" ]]; 
    then 
        evlvclassic="EVLV"; 
    else 
        evlvclassic="Classic"; 
fi; 

# Begin Function
printf "\r\nFACTFIND for $dediout pod-$cid\r\nThere are $count Installs on this pod\r\nAvailability Zone:$az\r\nMachine Type:$machine\r\nPlan:$plan\r\nPlatform Type: $evlvclassic\r\n\r\n=============================\r\n"; 

for i in $installs; 
    do installloc="/nas/content/live/$i"; 
        if [ -d $installloc ]; 
            then 
                cd /nas/content/live/$i 
                printf "\r\n"; 
                echo "INSTALL: $(echo $PWD | cut -d'/' -f4-)"; installdisk=$(( $installdisk + $(du -s -m $PWD | cut -d'/' -f1 | bc) )); disksize=$(du -hs $PWD | cut -d'/' -f1); 
                echo "Size of Filesystem: " $disksize; 
                echo "Size of Database: " $(dbsummary | grep "Total database size:" | cut -d':' -f4); 
                dbsize=$(dbsummary | grep "Total database size:" | cut -d':' -f4 | cut -d' ' -f2 | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' | bc);
                dbtotal=$(echo $dbtotal + $dbsize | bc);
                errorcount=$(zcat -f /var/log/nginx/$i.access.log* | grep "|50[0-9]|" | wc -l); 
                echo "50x Errors in All Logs: " $errorcount; errortotal=$(( $errortotal + $errorcount )); 
                static=$(zcat -f /var/log/nginx/$i.access.log* | wc -l); dyn=$(zcat -f /var/log/apache2/$i.access.log* | wc -l); comp=$(awk -v staticin=$static -v dynin=$dyn 'BEGIN { print staticin - dynin }');   cacheresult=$(awk -v compin=$comp -v staticincache=$static 'BEGIN { print (compin / staticincache)*100 }' | sed 's/^-.*/0/'); echo "Cacheability (%): " $cacheresult;
                echo "PHP-FPM Use: " $(awk "BEGIN {print ($dyn/$all)*100}" && echo "% ($dyn / $all hits)"); 
                echo "Average Daily CPU Runtime Use 7-days (BSPH): " $(instbsph=$(zcat -f /var/log/nginx/$i.access.log.* | awk -F '|' '{sum += $9} END {print substr((sum/7)/3600,0,6)}'); 
                echo $instbsph \/ $totbsph Total); 
            else 
                printf "\r\n ! ! ! Install $i Not Found ! ! ! \r\n"; 
        fi; 
    done; 

# Declare DB Total var

if (( $(echo "$dbtotal > 1000000" | bc -l) ))
    then
        dbprintin=$(echo $dbtotal / 1000 | bc);
        dbprintout=$(echo $dbprintin "TB");
    elif (( $(echo "$dbtotal > 10000" | bc -l) ))
        then
        dbprintin=$(echo $dbtotal / 1000 | bc);
        dbprintout=$(echo $dbprintin "GB");
    else
        dbprintout=$(echo $dbtotal "MB");
fi;


# Totals and Storage
printf "\r\n=============================\r\n\r\n"; 
echo "Total 50x Errors for Above Installs: " $errortotal; 
echo "Total DB Size for Above Installs: " $dbprintout;
echo "Total Local Storage Used for Above Installs: " $installdisk "MB"; 
echo "Total Local Storage Used for Account:"; df -h | grep "Filesystem\|nas" | column -t | awk '{print $2, $3, $4, $5}' | column -t; 
printf "\r\n";

# Metrics Link
if [[ $evlvfind =~ "evlv" ]];
    then
        echo "Visit EVLV Grafana Dashboard Here:"
        echo "https://metrics-platform.wpesvc.net/d/darwin/evolve?orgId=1&var-clusterID=$cid";
    else
        echo "Visit Classic Grafana Dashbard Here:"
        echo "https://metrics-platform.wpesvc.net/d/AaG8d2tMz/support-server-stats?orgId=1&var-host=pod-$cid";
    fi;

printf "\r\n";

# Return to Initial Dir
cd $initialdir