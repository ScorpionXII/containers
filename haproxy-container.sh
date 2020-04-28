#!/bin/bash

scriptHelp() {
	echo ""
	echo "Usage: $0 -n name -v version -p 80 -i /usr/local/etc/haproxy"
	echo -e "\t-n Container Name"
	echo -e "\t-v Version of the haproxy image"
	echo -e "\t-p Exposed 80 Port"
	echo -e "\t-i Path to mount haproxy.cfg in the docker image"
	exit 1 # Exit script
}

writeHAProxyConfig() {
	cat <<-EOF >/root/haproxy/haproxy.cfg
	global
	maxconn 50000
	log /dev/log local0

	defaults
	mode http
	timeout connect 5000ms
	timeout client 50000ms
	timeout server 50000ms

	backend www
	balance roundrobin
	#server www1 www1 check port 80
	#server www2 www2 check port 80
	#server www3 www3 check port 80
	server load1 localhost:8080 backup

	frontend app
	bind *:80
	default_backend www
	EOF
}

writeCloudService() {
	cat <<-EOF >/etc/systemd/system/cloudservice.service
	[Unit]
	Description=HAProxy Container

	[Service]
	ExecStart=/usr/bin/docker run --rm --name=$containerName -p $externalPort80:80 -v /root/haproxy:$imageConfigPath:ro haproxy:$version
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
	ExecStart=systemctl start cloudservice.service

	[Install]
	WantedBy=multi-user.target
	EOF
}

main() {
	systemctl start docker

	mkdir /root/haproxy

	writeHAProxyConfig
	writeCloudService
	writeStartupService

	systemctl daemon-reload
	systemctl start startup.service
	systemctl enable startup.service
}

# Get Script Options
while getopts ":n:v:p:i:" opt
do
	case "$opt" in
		n ) containerName=$OPTARG ;;
		v ) version=$OPTARG ;;
		p ) externalPort80=$OPTARG ;;
		i ) imageConfigPath=$OPTARG ;;
		? ) scriptHelp ;; # Print scriptHelp
	esac
done

# Print scriptHelp if there is missing parameter
if [ -z $containerName ] || [ -z $version ] || [ -z $version ] || [ -z $imageConfigPath ]
then
	echo "Some or all of the parameters are empty";
	scriptHelp
fi

# Execute Main Function
main