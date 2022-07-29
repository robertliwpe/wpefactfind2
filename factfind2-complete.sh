#!/bin/bash

# Intro and read installs variable
printf "\r\n"
printf '\e[1;34m%-6s\e[m' "WP Engine Factfind 2"
printf "\r\n"
echo "NOTE: This will ONLY work with WP Engine Production Pods and Servers."
echo "This may also take a long time on very large filesystems and databases."
echo "Also note that Cacheability scores of 0% or 100+% are likely inaccurate caused by non-use or atypical use of the install."
echo "Enter Install Names using Space as a Separator:"

read installsinit

# Declare Global Vars
installs="$installsinit"; 
installcount=0;
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

# Begin Function Whole of Pod
printf "\r\nFACTFIND for $dediout pod-$cid\r\nThere are $count Installs on this pod\r\nAvailability Zone:$az\r\nMachine Type:$machine\r\nPlan:$plan\r\nPlatform Type: $evlvclassic\r\n\r\n";

# Metrics Link
if [[ $evlvfind =~ "evlv" ]];
    then
        echo "Visit EVLV Grafana Dashboard Here:"
        echo "https://metrics-platform.wpesvc.net/d/darwin/evolve?orgId=1&var-clusterID=$cid";
    else
        echo "Visit Classic Grafana Dashbard Here:"
        echo "https://metrics-platform.wpesvc.net/d/AaG8d2tMz/support-server-stats?orgId=1&var-host=pod-$cid";
    fi;

printf "\r\n=============================\r\n"; 

# Load PHP-FPM/Apache and 50x Blocks
if [[ $evlvfind =~ "evlv" ]]; 
    then 
        printf "" ; 
    else 
        printf "\r\nHighest Load This Week:\r\n";
        printf "Load:   1m-avg  5m-avg  15m-avg\r\n" && sarqh | grep "AVG\|\=" 
fi; 

printf "\r\nInstalls Offending PHP-FPM / Apache\r\n(Last 48 Hrs)\r\n\r\n"; 

for i in $(ls -laSh /var/log/apache2/*.access.log /var/log/apache2/*.access.log.1 2>dev | head -20 | awk -F' ' '{print substr($9,18,100)}' | column -t); 
    do 
        installoffender=$(echo $i | cut -d'.' -f1); 
        offcount=$(zcat -f /var/log/apache2/$installoffender.access.log* | wc -l); 
        echo $offcount $installoffender; 
    done | column -t;

printf "\r\nInstalls with Highest 50x Errors\r\n(Last 48 Hrs)\r\n\r\n"; 

# This is the get50x command from Redshell
zgrep -E "\" 50[2,4] " /var/log/nginx/*.apachestyle.log /var/log/nginx/*.apachestyle.log.1 2>dev | sed -e "s_/var/log/nginx/__" -e "s_.apachestyle.log_ _" | awk '{ print $10,$1 }' | sort | uniq -c | sort -rn | head -20 | column -t;

printf "\r\n=============================\r\n"; 

# Per Install Factfind
for i in $installs; 
    do installloc="/nas/content/live/$i"; 
        if [ -d $installloc ]; 
            then 
                cd /nas/content/live/$i 
                printf "\r\n"; 
                installcount=$(( $installcount + 1 ));
                echo "INSTALL: $(echo $PWD | cut -d'/' -f4-)"; 
                disksize=$(du -s -m $PWD | cut -d'/' -f1 | bc); 
                installdisk=$(( $installdisk + $disksize )); 

                # Declare Disk Size per Install var
                if (( $(echo "$disksize > 1000000" | bc -l) ))
                    then
                        diskprintin=$(echo $disksize / 1000 | bc);
                        diskprintout=$(echo $diskprintin "TB");
                    elif (( $(echo "$disksize > 10000" | bc -l) ))
                        then
                        diskprintin=$(echo $disksize / 1000 | bc);
                        diskprintout=$(echo $diskprintin "GB");
                    else
                        diskprintout=$(echo $disksize "MB");
                fi;

                echo "Size of Filesystem: " $diskprintout; 
                dbsize=$(echo $(wp db size --size_format=MiB --decimals=2 --skip-themes --skip-plugins --quiet) | tr -d $'\r' | bc );
                echo "Size of Database: " $dbsize "MB"; 
                dbtotal=$(echo $dbtotal + $dbsize | bc);
                errorcount=$(zcat -f /var/log/nginx/$i.access.log* | grep "|50[0-9]|" | wc -l); 
                echo "50x Errors in All Logs: " $errorcount; errortotal=$(( $errortotal + $errorcount )); 
                static=$(zcat -f /var/log/nginx/$i.apachestyle.log* | grep -v "jpg\|jpeg\|png\|svg\|gif\|webp\|woff\|woff2\|ttf\|otf\|xml\|css\|ico\|\.js\|txt\|pdf\|mov\|mp4\|mp3\|aiff\|mpg\|mpeg\|ogg" | wc -l | bc); 
                dyn=$(zcat -f /var/log/apache2/$i.access.log* | wc -l | bc); 
                comp=$(awk -v staticin=$static -v dynin=$dyn 'BEGIN { print staticin - dynin }' | bc);   

                # Correct for wierd results in cacheresult var
                cacheresult=$(awk -v compin=$comp -v staticincache=$static 'BEGIN { print ((compin+1) / (staticincache+1))*100 }' | sed 's/^-.*/0/'); 

                if (( $(echo "$cacheresult > 100" | bc -l) ))
                    then
                        cacheresult=$(echo 100 | bc);
                    else
                        cacheresult=$(echo $cacheresult | bc);
                fi;

                echo "Cacheability (%): " $cacheresult;
                echo "PHP-FPM / Apache Use: " $(awk "BEGIN {print ($dyn/$all)*100}" && echo "% ($dyn / $all hits)"); 
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
echo "Total Number of Installs Analyzed: " $installcount;
echo "Total 50x Errors for Above Installs: " $errortotal; 
echo "Total DB Size for Above Installs: " $dbprintout;
echo "Total Local Storage Used for Above Installs: " $installdisk "MB"; 
echo "Total Local Storage Used for Account:"; df -h | grep "Filesystem\|nas" | column -t | awk '{print $2, $3, $4, $5}' | column -t; 
printf "\r\n";

# Return to Initial Dir
cd $initialdir