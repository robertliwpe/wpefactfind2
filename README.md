# WP Engine Factfind V2

Factfind command currently only works in Classic GCP and AWS configurations.

This updated Factfind will work on both Classic and EVLV configurations (in EVLV configurations no infrastructure utilization data is provided due to the isolation between service containers this will still need to be pulled from Grafana - thankfully it does provide you a link to the specific dashboard you will need to access).

Currently how it works is via `wget` command, which pulls a shell script from Github and then executes that script on the server. Nothing is stored nor changed on the server.

Simply input the names of the Installs concerned (they MUST be on the specific pod or EVLV cluster you are currently SSH'd into).

This will only work for WP Engine pods and clusters, and will require Redshell access (it uses some Redshell commands). This is NOT customer facing and will not work via SSH Gateway.

There are 2 versions:

### Install Only Factfind: https://gist.github.com/robertliwpe/fb055c87790ef74818f22d30acf0d9fa

To invoke, `gogo` or `ssh` into your chosen pod/EVLV cluster, paste the following command into your terminal and press enter:

`source <(wget -nv -O - https://gist.githubusercontent.com/robertliwpe/fb055c87790ef74818f22d30acf0d9fa/raw/d3fb8d46c3566266147af16c344d96a4d26b6908/factfind2.sh)`

### Combination Server & Install Factfind (Currently BETA): https://gist.github.com/robertliwpe/e3d351e7423ba667e940f41193029f5f

To invoke, `gogo` or `ssh` into your chosen pod/EVLV cluster, paste the following command into your terminal and press enter:

`source <(wget -nv -O - https://gist.githubusercontent.com/robertliwpe/e3d351e7423ba667e940f41193029f5f/raw/e4814f6fa25f1fcaa0c364a01a04f3d310f6d8be/factfind2-complete.sh)`