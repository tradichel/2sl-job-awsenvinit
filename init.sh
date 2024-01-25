#!/bin/bash -e
# https://github.com/tradichel/2sl-job-awsenvinit
# init.sh
# author: @teriradichel @2ndsightlab
# Description: Run this script in a new AWS acocunt 
# after you have run the script in this repository:
# https://github.com/tradichel/2sl-job-awsorginit
#
# This script to deploys the minimal resources for a
# 2nd Sight Lab Job Execution Environment
##############################################################

source 
if [ -d 2sl-jobexecframework ]; then
 rm -rf 2sl-jobexecframework
fi

if [ -d 2sl-job-awsenvinit ]; then
	rm -rf 2sl-job-awsenvinit
fi

if [ -d 2sl-jobconfig-awsdeploy ]; then
  rm -rf 2sl-jobconfig-awsdeploy
fi

buildxversion=$(docker buildx version | cut -d " " -f2 | cut -d "+" -f1)
echo "Buildx Version: $buildxversion"

if [ "$buildxversion" == "v0.0.0" ]; then
	git clone https://github.com/docker/buildx.git
	cd buildx
	sudo make install
	mkdir -p ~/.docker/cli-plugins #no sudo
	sudo install bin/build/buildx ~/.docker/cli-plugins/docker-buildx
	cd ..
	rm -rf buildx
	buildxversion=$(docker buildx version)
	echo "Buildx updated to version: $buildxversion"
	echo "Restart CloudShell to free up space and run this script again"
fi

#clone the repositories to CloudShell
git clone https://github.com/tradichel/2sl-jobexecframework.git
git clone https://github.com/tradichel/2sl-job-awsenvinit.git
git clone https://github.com/tradichel/2sl-jobconfig-awsdeploy.git

#deploy the job config ssm parameter
cd 2sl-jobconfig-awsdpeloy/
ssm_param_name="/job/root-admin/organizations/organizationalunit/dev"
source ./2sl-jobexecframework/resources/ssm/parameters/parameter_functions.sh
set_ssm_parameter_job_config $ssm_param_name
exit

#run the job
cd ../2sl-jobexecframework/
./scripts/build.sh awsenvinit

sudo yum install jq -y
creds=$(curl -H "Authorization: $AWS_CONTAINER_AUTHORIZATION_TOKEN" $AWS_CONTAINER_CREDENTIALS_FULL_URI 2>/dev/null)
profile='root'
region=$AWS_REGION

accesskeyid="$(echo $creds | jq -r ".AccessKeyId")"
secretaccesskey="$(echo $creds | jq -r ".SecretAccessKey")"
sessiontoken="$(echo $creds | jq -r ".Token")"

echo "********************************************"
echo "Pass credentials to container"
echo "********************************************"
parameters="\
  profile=root-admin,\
  accesskey=$accesskeyid,\
  secretaccesskey=$secretaccesskey,\
  sessiontoken=$sessiontoken,\
  region=$AWS_REGION,\
	job_ssm_parameter=$ssm_parameter_name"

#remove any spaces so the parameter list is treated as a single argument passed to the container
parameters=$(echo $parameters | sed 's/ //g')

echo "********************************************"
echo "Run the container $image and execute the job $job_parameter"
echo "********************************************"
docker run awsenvinit $parameters

#clear space in CloudShell
sudo docker system prune -y
sudo yum clean all
history -c
./scripts/delete_all_images_and_containers.sh
cd ..
rm -rf 2sl*
