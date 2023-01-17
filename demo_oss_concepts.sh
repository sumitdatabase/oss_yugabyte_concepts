#/bin/bash

version=2.15.3.2-b1

# For higher version, this demo breaks - see Issues-15692. Supposed to be fixed in 2.17.1

function pause() 
{ 
 echo "\n Please press <return> key to continume ... \n" ; read -s -n 1 
}

# Start of setting up the 3 node cluster for several scenarios.

echo "\n In this demo, we will bring up yugabyted different continents across the world - Asia, Eurupe, Africa, America, Australia. As each continent 
joins the clister,  we will watch the intraction with number of nodes, tservers, masters, RF factors. 
Along the way we will also watch  what happens to tables created along the way \n"

pause

echo "\n First create a docker bridge network that all docker containers - in each *continent* can talk to each other and join the cluster \n"

docker network remove yb-net
docker network create -d bridge yb-net

pause
echo "\n Now we bring up the cluster - one node per continet at a time - first Americas \n"

# Bring up a 3 node cluster in docker containers. If you are on Mac on Arm64 chip and get a warning that the docker container was meant for Linux/x86-64, you can ignore it. Sending errors to bit bucket.

docker run -d --network yb-net --name yb-am-1 -p5001:5433 -p7001:7000 -p9001:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --listen yb-am-1 \
 --master_flags="placement_zone=1,placement_region=am,placement_cloud=cloud" \
 --tserver_flags="placement_zone=1,placement_region=am,placement_cloud=cloud"  2>/dev/null

echo "\n Watch the cluster config 127.0.0.1:7001 after every container start up - takes about 10 seconds "

echo "\n After the first node creates the cluster, from http://localhost:7001/, # of Tserver = 1, Master =1, RF = 1"

pause

# At this stage, if you want you can create a table

echo "\n Now with just one node in the cluster, creating a test table after 20 seconds \n "

sleep 20
ysqlsh -p 5001 -U yugabyte -ec "create table t1 ( c1 int ) " ;

pause

echo "\n Now we will add the next node/continent - Africa \n"

docker run -d --network yb-net --name yb-af-1 -p5002:5433 -p7002:7000 -p9002:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --listen yb-af-1 --join yb-am-1 \
 --master_flags="placement_zone=1,placement_region=af,placement_cloud=cloud" \
 --tserver_flags="placement_zone=1,placement_region=af,placement_cloud=cloud"  2>/dev/null

#  docker run -d --network yb-net --name yb-am-1 -p5001:5433 -p7001:7000 -p9001:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --advertise_address=127.0.0.1


echo "\n As the 2nd node joins the cluster, from http://localhost:7001/,  # of Tserver = 2, Master =2, RF = 1"

pause

echo "\n Now with 2 nodes in the cluster, creating 2nd test table after 20 seconds - this time will connect to the 2nd node after 20 seconds \n"

sleep 20
ysqlsh -p 5002 -U yugabyte -ec "create table t2 ( c1 int ) " ;

pause

echo "\n Now we add a third continent, Europe"


docker run -d --network yb-net --name yb-eu-1 -p5003:5433 -p7003:7000 -p9003:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --listen yb-eu-1 --join yb-am-1 \
 --master_flags="placement_zone=1,placement_region=eu,placement_cloud=cloud" \
 --tserver_flags="placement_zone=1,placement_region=eu,placement_cloud=cloud"  2>/dev/null

echo "\n When all 3 nodes are added, watch that the  number of Tserver = 3, Master =3, RF = 3. RF jumped from 1 to 3"

pause

echo "\n Now with 3 nodes in the cluster, creating 3rd test table - this time will connect to the 3rd node - it will fail as placement is invalid. Again wait 20 seconds first"

sleep 20
ysqlsh -p 5003 -U yugabyte -ec "create table t3 ( c1 int ) " ;

pause

echo "\n Let's fix the placement issue \n"

docker exec -i yb-am-1 yb-admin -master_addresses yb-am-1:7100,yb-af-1:7100,yb-eu-1:7100 modify_placement_info cloud.am.1:1,cloud.af.2:1,cloud.eu.1:1 3

pause

echo "\n Now with 3 nodes in the cluster, placement modified, creating 3rd test table - this time will connect to the 3rd node - it will succeed"

ysqlsh -p 5003 -U yugabyte -ec "create table t3 ( c1 int ) " ;

echo "\n Watch that the number of tablets for table t1 is 1, for t2 2, and for t3 3  at localhost:9001/tables \n"#/bin/bash


# Add two more nodes to the cluster - 

 echo "\n Adding a 4th node to the cluster - Asia \n"

pause

docker run -d --network yb-net --name yb-as-1 -p5004:5433 -p7004:7000 -p9004:9000 yugabytedb/yugabyte:$version \
yugabyted start --daemon=false --listen yb-as-1 --join yb-am-1 \
 --master_flags="placement_zone=1,placement_region=as,placement_cloud=cloud" \
--tserver_flags="placement_zone=1,placement_region=as,placement_cloud=cloud"  2>/dev/null

echo "\n As the 4th node joins the cluster, from http://localhost:7001/,  # of Tserver = 4, Master =3, RF = 3"

pause

echo "\n Adding a 5th node to the cluster - Australia \n"

pause

docker run -d --network yb-net --name yb-au-1 -p5005:5433 -p7005:7000 -p9005:9000 yugabytedb/yugabyte:$version \
yugabyted start --daemon=false --listen yb-au-1 --join yb-am-1 \
 --master_flags="placement_zone=1,placement_region=au,placement_cloud=cloud" \
--tserver_flags="placement_zone=1,placement_region=au,placement_cloud=cloud"  2>/dev/null

echo "\n As the 5th node joins the cluster, from http://localhost:7001/,  # of Tserver = 5, Master =3, RF = 3"

pause

echo "\n By changing the placement information, you can change RF to any number - like RF 4 with 5 tserver nodes - leaving one node Asia out \n"
docker exec -i yb-am-1 yb-admin -master_addresses yb-am-1:7100,yb-af-1:7100,yb-eu-1:7100 modify_placement_info cloud.am.1:1,cloud.af.1:1,cloud.eu.1:1,cloud.au.1:1 4

pause
echo "\n In addition, it is possible to have RF to any number - and not every node needs to have a copy - here 7 copies leaving one node Australia out"
docker exec -i yb-am-1 yb-admin -master_addresses yb-am-1:7100,yb-af-2:7100,yb-eu-1:7100 modify_placement_info cloud.am.1:1,cloud.af.1:2,cloud.eu.1:2,cloud.ap.1:2 7

echo "\n Thank you that is end of this demo \n"
