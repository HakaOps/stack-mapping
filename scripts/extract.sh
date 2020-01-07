#!/bin/bash
#
# Author: Vagner Rodrigues Fernandes <vagner.rodrigues@gmail.com>
# Description: Match data from Consul KV on CSV report.
# Version: 1.0.0
#
# Usage: ./extract.sh <CSV_OUTPUT_FILE>
#

## Enviroments

# Arguments env
OUTPUT_FILE=$1

# Consul URL Config
CONSUL_URL="http://consul.foo.bar:8500"

# AWS JSON
AWS_JSON="http://consul.foo.bar:8500/v1/kv/aws?raw"

# Consul Match Index
HW_LIST=("net/hostname" "generic/os" "hardware/cpu" "hardware/cpu_model" "hardware/memory" "hardware/disk")
NGINX_LIST=("server_name" "listen" "root" "location" "proxy_pass")
IIS_LIST=("site" "app" "apppool" "vdir")
AWS_LIST=("s3" "ec2" "ec2-eips" "ec2-network-interfaces" "ec2-subnets" "ec2-ebs" "ec2-egpu" "ec2-vpcs" "ec2-security-groups" "ec2-nat-gateways" "ec2-internet-gateways" "elb" "elbv2" "autoscaling" "route53" "rds" "cloudtrail" "lightsail" "cloudformation" "cloudsearch" "datapipeline"  "es" "storagegateway"  "clouddirectory" "efs" "cloudwatch" "dynamodb" "elasticbeanstalk" "kms"  "alexa" "sqs" "cloudfront" "hsm" "redshift"  "ecs" "sns"  "workmail"  "apigateway" "codestar" "secrets" "neptune" "batch" "acm" "acm-pca"  "glacier" "mq" "emr"  "elasticache" "eks" "lambda")

## Functions

# Get host index function
function getindex() {
	INDEX_PATH=$1
	INDEX_MATCH=$2
	curl -s "$CONSUL_URL/v1/kv/$INDEX_PATH/?recurse" | \
		jq '.[].Key' | \
		cut -d\/ -f$INDEX_MATCH | \
		sed 's/\"//g' | \
		grep "."
}

# Usage function
function usage()
{
    echo "./extract.sh <CSV_OUTPUT_FILE>"
}

## Syntax Check 
if [ -z $1 ]; then
	usage
	exit
fi

## Main

# Input hardware data header CSV
echo "IP;HOSTNAME;OS;CPU_CORES;CPU_MODEL;MEMORY_MB;HARDWARE_DISK" > $OUTPUT_FILE

echo "Generating HOSTS data"
# Loop for get consul hardware data  
for XHOST in `getindex hosts.index 2`; do

	VAR="$XHOST"
	for x in "${HW_LIST[@]}"; do
		OS_SUFFIX=$(curl -s "$CONSUL_URL/v1/kv/hosts/$XHOST/generic/os.suffix?raw" | sed "s/\;//g")
		if [ "$OS_SUFFIX" == "windows" ] && [ "$x" == "hardware/disk" ]; then
			VAR+=";"$(curl -s "$CONSUL_URL/v1/kv/hosts/$XHOST/$x?raw" | sed "s/\;//g" | grep FileSystem | awk '{ print $1 " - used:" $2 " free: " $3 }')
		else
			VAR+=";"$(curl -s "$CONSUL_URL/v1/kv/hosts/$XHOST/$x?raw" | sed "s/\;//g")
		fi
	done

	# Input match consul data 
	echo $VAR >> $OUTPUT_FILE

done

echo -e "\n\nNGINX INFORMATIONS" >> $OUTPUT_FILE
echo "IP;NGINX_CONFIG;NGINX_VHOST;NGINX_PORT;NGINX_DIR;LOCATION;PROXY" >> $OUTPUT_FILE

echo "Generating NGINX data"
# Loop for get consul nginx data  
for XHOST in `getindex hosts.index 2`; do

	# Check Nginx Informations
	if [ "$(curl -s "$CONSUL_URL/v1/kv/hosts/$XHOST/nginx/vhosts.index?recurse")" ]; then

		for XVHOSTS in `getindex hosts/$XHOST/nginx/vhosts.index 5`; do

			VAR="$XHOST"
			VAR+=";$XVHOSTS"

			for y in "${NGINX_LIST[@]}"; do
				VAR+=";"$(curl -s "$CONSUL_URL/v1/kv/hosts/$XHOST/nginx/vhosts/$XVHOSTS/$y?raw" | sed "s/\;//g" | tr -d "\n")
			done
			
			# Input nginx match data
			echo "$VAR" >> $OUTPUT_FILE

		done

	fi

done


echo -e "\n\nIIS INFORMATIONS" >> $OUTPUT_FILE
echo "IP;SITES;APPS;APP POOLS;VIRTUAL DIRS" >> $OUTPUT_FILE

echo "Generating IIS data"
# Loop for get consul iis data  
for XHOST in `getindex hosts.index 2`; do

	# Check Nginx Informations
	if [ "$(curl -s "$CONSUL_URL/v1/kv/hosts/$XHOST/iis?recurse")" ]; then

		VAR="$XHOST"
		VAR+=";$XVHOSTS"

		for y in "${IIS_LIST[@]}"; do
			VAR+=";"$(curl -s "$CONSUL_URL/v1/kv/hosts/$XHOST/iis/$y?raw" | sed "s/\,/-/g" | tr -d "\n")
		done
			
		# Input iis match data
		echo "$VAR" >> $OUTPUT_FILE

	fi

done

echo "Generating AWS data"
# Loop for get AWS data
curl -s $AWS_JSON > /tmp/__out_aws_json.$$
mkdir /tmp/__out_aws_csv.$$

echo -e "\n\nAWS Assessment\n" >> $OUTPUT_FILE
rm -rf $OUTPUT_FILE.html
mkdir $OUTPUT_FILE.html
cat ./html/top.template > $OUTPUT_FILE.html/index.html

for XAWS in "${AWS_LIST[@]}"; do
	python json-to-csv/json_to_csv.py $XAWS /tmp/__out_aws_json.$$ /tmp/__out_aws_csv.$$/$XAWS.csv &>/dev/null
	echo -e "$XAWS" >> $OUTPUT_FILE
	cat /tmp/__out_aws_csv.$$/$XAWS.csv >> $OUTPUT_FILE
	echo -e "--\n\n" >> $OUTPUT_FILE

	# Convert to HTML
        csv2html -o /tmp/__out_aws_csv.$$/$XAWS_converted.html /tmp/__out_aws_csv.$$/$XAWS.csv

        echo "<h2 class=\"sub-header\">$XAWS</h2>" >> /tmp/__out_aws_csv.$$/$XAWS.html
        echo "<div class=\"table-responsive\">" >> /tmp/__out_aws_csv.$$/$XAWS.html
        echo "<table class=\"table table-striped\">" >> /tmp/__out_aws_csv.$$/$XAWS.html
        echo "<thead><tr>" >> /tmp/__out_aws_csv.$$/$XAWS.html
        grep "<th>" /tmp/__out_aws_csv.$$/$XAWS_converted.html | tail -n1 >> /tmp/__out_aws_csv.$$/$XAWS.html
        echo "</th></thead>" >> /tmp/__out_aws_csv.$$/$XAWS.html
        echo "<tbody>" >> /tmp/__out_aws_csv.$$/$XAWS.html
        grep "<td>" /tmp/__out_aws_csv.$$/$XAWS_converted.html | tail -n1 >> /tmp/__out_aws_csv.$$/$XAWS.html
        echo "</tbody></table></div>" >> /tmp/__out_aws_csv.$$/$XAWS.html

        cat /tmp/__out_aws_csv.$$/$XAWS.html >> $OUTPUT_FILE.html/index.html 

        rm -f /tmp/__out_aws_csv.$$/$XAWS.html
        rm -f /tmp/__out_aws_csv.$$/$XAWS_converted.html
        rm -f /tmp/__out_aws_csv.$$/$XAWS.csv
done

cat ./html/footer.template >> $OUTPUT_FILE.html/index.html
cp -r ./html/assets ./html/bootstrap $OUTPUT_FILE.html/ 

rm -f /tmp/__out_aws_json.$$
rmdir /tmp/__out_aws_csv.$$
