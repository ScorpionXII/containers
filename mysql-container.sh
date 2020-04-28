#!/bin/bash

scriptHelp() {
	echo ""
	echo "Usage: $0 -n name -v version -p 3306 -m [masterPwd] -c [utf8mb4] -l [utf8mb4_unicode_ci]"
	echo -e "\t-n Container Name"
	echo -e "\t-v Version of the mysql image"
	echo -e "\t-p Exposed 3306 Port"
	echo -e "\t-m Master root password"
	echo -e "\t-c Charset"
	echo -e "\t-l Collation"
	exit 1 # Exit script
}

writeCloudService() {
	[ -z $rootPassword ] && rootPassword="password"
	[ -z $charset ] && charset="utf8mb4"
	[ -z $collation ] && collation="utf8mb4_unicode_ci"

	cat <<-EOF >/etc/systemd/system/cloudservice.service
	[Unit]
	Description=MySQL Container
	
	[Service]
	ExecStart=/usr/bin/docker run --name $containerName -p $externalPort3306:3306 -e MYSQL_ROOT_PASSWORD=$rootPassword mysql:$version --character-set-server=$charset --collation-server=$collation
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

	writeCloudService
	writeStartupService

	systemctl daemon-reload
	systemctl start startup.service
	systemctl enable startup.service
}

# Get Script Options
while getopts ":n:v:p:m:c:l:" opt
do
	case "$opt" in
		n ) containerName=$OPTARG ;;
		v ) version=$OPTARG ;;
		p ) externalPort3306=$OPTARG ;;
		m ) rootPassword=$OPTARG ;;
		c ) character=$OPTARG ;;
		l ) collation=$OPTARG ;;
		? ) scriptHelp ;; # Print scriptHelp
	esac
done

# Print scriptHelp if there is missing parameter
if [ -z $containerName ] || [ -z $version ] || [ -z $externalPort3306 ]
then
	echo "Some or all of the parameters are empty";
	scriptHelp
fi

# Execute Main Function
main