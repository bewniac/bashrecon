#!/bin/zsh

# Variables
BINDIR="$HOME/projects/bashrecon/bin"
CWD="$HOME/projects/bashrecon"
APT_DEPS="git make build-essential ruby ruby-dev unzip nmap jq chromium-browser"

# clean
if [ $1 = "--clean" ]
then 
    echo "Cleaning up"
    rm -rf bin
    rm -rf nuclei-templates
    rm -f $HOME/go/bin/amass
    rm -f $HOME/go/bin/crobat
    rm -f $HOME/go/bin/subfinder
    rm -f $HOME/go/bin/httpx
    rm -f $HOME/go/bin/nuclei
    sudo rm -f /usr/local/bin/massdns

    echo "Optionally, remove installed dependencies:"
    echo "sudo apt remove $APT_DEPS && sudo rm -rf /usr/local/go"
    exit 0 
fi


# Create bin directory
if [ -d $BINDIR ];
then
    echo "Already installed everything. To reinstall use --clean first"
    exit 0
else
    mkdir bin
fi

# recon deps
sudo apt update && sudo apt install $APT_DEPS
wget https://golang.org/dl/go1.17.2.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.17.2.linux-amd64.tar.gz
rm go1.17.2.linux-amd64.tar.gz

# Crobat
go get github.com/cgboal/sonarsearch/cmd/crobat
cp `which crobat` $BINDIR/crobat

# Nuclei
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
git clone https://github.com/projectdiscovery/nuclei-templates.git
cp `which nuclei` $BINDIR/

# HttpX
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
cp `which httpx` $BINDIR/

# Subfinder
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
cp `which subfinder` $BINDIR/

# WPScan
sudo gem install wpscan
cp `which wpscan` $BINDIR/

# MassDNS
git clone https://github.com/blechschmidt/massdns.git
cd massdns && make && sudo make install 
cp `which massdns` $BINDIR/
cd $CWD && sudo rm -r massdns

# Amass
wget https://github.com/OWASP/Amass/releases/download/v3.14.1/amass_linux_amd64.zip
cp amass_linux_amd64/amass bin/
rm -r amass_linux_amd64 amass_linux_amd64.zip

# Nmap
cp `which nmap` $BINDIR/nmap

# Aquatone
wget https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip
unzip -q -o -d bin/ aquatone_linux_amd64_1.7.0.zip -x "README.md" "LICENSE.txt"
rm -f aquatone_linux_amd64_1.7.0.zip

# DNSRecon
git clone https://github.com/darkoperator/dnsrecon.git
cd dnsrecon && python3 -m pip install -r requirements.txt && cd $CWD
ln -s $CWD/dnsrecon/dnsrecon.py $BINDIR/dnsrecon
