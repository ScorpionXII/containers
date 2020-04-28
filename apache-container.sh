#!/bin/bash

scriptHelp() {
	echo ""
	echo "Usage: $0 -n name -v version -p [80] -e [false] -s [443]"
	echo -e "\t-n Container Name"
	echo -e "\t-v Version of the httpd image"
	echo -e "\t-p Exposed 80 Port"
	echo -e "\t-e Enable SSL"
	echo -e "\t-s Exposed 443 Port"
	exit 1 # Exit script
}

writeCloudService() {
	cat <<-EOF >/etc/systemd/system/cloudservice.service
	[Unit]
	Description=Apache Container

	[Service]
	ExecStart=/usr/bin/docker run --rm --name=$containerName -p $externalPort80:80 httpd:$version
	ExecStop=/usr/bin/docker stop $containerName
	ExecStopPost=/usr/bin/docker rm $containerName
	EOF
}

writeStartupService() {
	cat <<-EOF >/etc/systemd/system/startup.service
	[Unit]
	Description=Startup Service

	[Service]
	Type=oneshot
	ExecStart=systemctl start docker
	ExecStart=$([ $enableHttps == true ] && "systemctl start cloudservice.ssl.service" || "systemctl start cloudservice.service")

	[Install]
	WantedBy=multi-user.target
	EOF
}

writeCloudServiceSSL() {
	[ -z $externalPort443 ] && externalPort443=443
	cat <<-EOF >/etc/systemd/system/cloudservice.ssl.service
	[Unit]
	Description=Apache Container

	[Service]
	ExecStart=/usr/bin/docker run --rm --name=$containerName -p $externalPort80:80 $externalPort443:443 -v /root/httpd.conf:/usr/local/apache2/conf/httpd.conf -v /root/server.key:/usr/local/apache2/conf/server.key -v /root/server.cert:/usr/local/apache2/conf/server.crt httpd:$version
	ExecStop=/usr/bin/docker stop $containerName
	ExecStopPost=/usr/bin/docker rm $containerName
	EOF
}

generateCertificates() {
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -keyout /root/server.key -out /root/server.cert -subj "/C=PH/ST=Philipines/L=Philipines/O=Globe/CN=globe.com.ph"
}

modifyConfiguration() {
	docker run --rm --name temp-httpd httpd:$version cat /usr/local/apache2/conf/httpd.conf > /root/httpd.conf
	sed -i -e 's/^#\(Include .*httpd-ssl.conf\)/\1/' /root/httpd.conf
	sed -i -e 's/^#\(LoadModule .*mod_ssl.so\)/\1/' /root/httpd.conf
	sed -i -e 's/^#\(LoadModule .*mod_socache_shmcb.so\)/\1/' /root/httpd.conf
}

main() {
	systemctl start docker

	generateCertificates
	modifyConfiguration

	if [ $enableHttps == "true" ] 
	then
		writeCloudServiceSSL
	else
		writeCloudService
	fi

	systemctl daemon-reload
	systemctl start startup.service
	systemctl enable startup.service
}

# Get Script Options
while getopts ":n:v:p:e:s:" opt
do
	case "$opt" in
		n ) containerName=$OPTARG ;;
		v ) version=$OPTARG ;;
		p ) externalPort80=$OPTARG ;;
		e ) enableHttps=$OPTARG ;;
		s ) externalPort443=$OPTARG ;;
		? ) scriptHelp ;; # Print scriptHelp
	esac
done

echo $containerName
echo $version
echo $externalPort80
echo $enableHttps

# Print scriptHelp if there is missing parameter
if [ -z $containerName ] || [ -z $version ] || [ -z $externalPort80 ]
then
	echo "Some or all of the parameters are empty";
	scriptHelp
fi

# Execute Main Function
main