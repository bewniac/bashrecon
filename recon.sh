#!/bin/zsh

function usage () {
    echo "Usage: $1 example.com"
}


if [ -z "$1" ];
then
    usage $0
    exit 0
fi

TARGET=$1
RESULTDIR="result/$TARGET/$(date +%y%m%d_%H%M)"
mkdir -p $RESULTDIR

# Clean resolver list
wget https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt -O resolvers.txt

# DNSrecon
./bin/dnsrecon -d $TARGET -j $RESULTDIR/dnsrecon.json

# DNSrecon for new tlds on target
./bin/dnsrecon -t tld -d $TARGET -j $RESULTDIR/tlds.json
# TLDs from DNSrecon
jq -cr '.[1:] | .[] | .[].name' $RESULTDIR/tlds.json | sort | uniq >> tlds.txt

# Amass
./bin/amass enum -nolocaldb -d $TARGET -json $RESULTDIR/amass.json &

# Subfinder
./bin/subfinder -silent -d $TARGET -oJ -o $RESULTDIR/subfinder.json &

# Crobat 
./bin/crobat -s $TARGET | tee $RESULTDIR/crobat.txt &

# Wait until everything is done
wait

echo "Creating subdomains.txt and cleaning it up"
jq -r .name >> $RESULTDIR/subdomains.txt $RESULTDIR/amass.json
jq -r .host >> $RESULTDIR/subdomains.txt $RESULTDIR/subfinder.json
cat $RESULTDIR/crobat.txt >> $RESULTDIR/subdomains.txt
sort $RESULTDIR/subdomains.txt | uniq >> $RESULTDIR/tmp.txt
mv $RESULTDIR/tmp.txt $RESULTDIR/subdomains.txt

./bin/massdns -o J -r resolvers.txt $RESULTDIR/subdomains.txt -w $RESULTDIR/massdns.json & 
./bin/httpx -silent -l $RESULTDIR/subdomains.txt -o $RESULTDIR/httpx.json -json & 

# Wait until everything is done
wait 

# Fix massdns output
jq -cr  '.data.answers[] | select(.type=="A") | .data' 2>/dev/null $RESULTDIR/massdns.json > $RESULTDIR/ipv4.txt
jq -cr  '.data.answers[] | select(.type=="AAAA") | .data' 2>/dev/null $RESULTDIR/massdns.json > $RESULTDIR/ipv6.txt
jq -cr  '.data.answers[] | select(.type=="CNAME") | .data' 2>/dev/null $RESULTDIR/massdns.json > $RESULTDIR/cname.txt

cat $RESULTDIR/httpx.json | jq -r .url >> $RESULTDIR/webservers.txt

# Nuclei 
./bin/nuclei -t / -l $RESULTDIR/webservers.txt -o $RESULTDIR/nuclei.json -json -silent -irr -r resolvers.txt & 
./bin/nmap -v --top-ports 10000 -g 53 -sV -iL $RESULTDIR/ipv4.txt -oA $RESULTDIR/nmap & 

# Wait until everything is done
wait

# TODO: Cleanup & parse nuclei result
# jq -cr '."template-id", .info.severity, .info.name, ."curl-command"' $RESULTDIR/nuclei.json

# Filter technologies based on match
# jq -cr 'select(."template-id"=="tech-detect" ) as $result 
#        | [$result.host, $result."matcher-name"]
#        | @csv' nuclei.json

# Filter out relevant data and export to CSV
echo "name,host,severity,matcher-name" > nuclei.csv
jq -cr '. as $result 
        | [$result.info.name,$result.host,$result.info.severity,$result."matcher-name"] 
        | @csv' nuclei.json | tr -d "\"" >> nuclei.csv

# Get wordpress nuclei results
jq -cr 'select(."template-id" | contains("wordpress")) | .host' $RESULTDIR/nuclei.json 2>/dev/null | cut -d ":" -f 1-2 | sort | uniq >> $RESULTDIR/wordpress.txt

# WPScan
for url in `cat $RESULTDIR/wordpress.txt`;
do
    FILENAME=`echo $url | cut -d "/" -f 3`
    wpscan --rua -o $RESULTDIR/wpscan_$FILENAME -e ap --disable-tls-checks --ignore-main-redirect --url $url &
done

# Auquatone on nmap xml
cat $RESULTDIR/nmap.xml | ./bin/aquatone -silent -ports xlarge -nmap -out $RESULTDIR/aquatone/ &

# Always end with a wait
wait 