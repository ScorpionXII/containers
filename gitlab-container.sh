#!/bin/bash

scriptHelp() {
	echo ""
	echo "Usage: $0 -n name -v version"
	echo -e "\t-n Container Name"
	echo -e "\t-v Version of the gitlab image"
	exit 1 # Exit script
}

writeCloudService() {
	cat <<-EOF >/etc/systemd/system/cloudservice.service
	[Unit]
	Description=Gitlab Container

	[Service]
	ExecStart=/usr/bin/docker run --rm \
		--hostname=gitlab.example.com \
		--publish 443:443 --publish 80:80 --publish 2222:22 \
		--name=$containerName \
		--volume=/root/gitlab/config:/etc/gitlab \
		--volume=/root/gitlab/logs:/var/log/gitlab \
		--volume=/root/gitlab/data:/var/opt/gitlab \
		gitlab/gitlab-ce:$version
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

	mkdir /root/gitlab

	writeCloudService
	writeStartupService

	systemctl daemon-reload
	systemctl start startup.service
	systemctl enable startup.service
}

# Get Script Options
while getopts ":n:v:" opt
do
	case "$opt" in
		n ) containerName=$OPTARG ;;
		v ) version=$OPTARG ;;
		? ) scriptHelp ;; # Print scriptHelp
	esac
done

# Print scriptHelp if there is missing parameter
if [ -z $containerName ] || [ -z $version ]
then
	echo "Some or all of the parameters are empty";
	scriptHelp
fi

# Execute Main Function
main