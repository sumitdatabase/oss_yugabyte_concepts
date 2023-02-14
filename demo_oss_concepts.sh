#/bin/bash

function pause() 
{ 
 echo "\n Please press <return> key to continume ... \n" ; read -s -n 1
}
version=2.15.3.2-b1

# For higher version, this demo breaks - see Issues-15692. Supposed to be fixed in 2.17.1

# Start of setting up the 3 node cluster for several other scenarios.

echo "\n In this demo, we will bring up yugabyted different continents across the world - Asia, Eurupe, Africa, America, Australia. As each continent 
joinst the clister,  we will watch the intraction with number of nodes, tservers, masters, RF factors and what happens to tables created along the way.
If you do not have lynx installed, comment lynx out or install it. \n"

pause

echo "\n First create a docker bridge network that all docker containers - in each *continent* can talk to each other and join the cluster \n"

docker network remove yb-net
docker network create -d bridge yb-net

pause
echo "\n Now we bring up the cluster - one node per continent at a time - first Americas \n"

# Bring up a 3 node cluster in docker containers. If you are on Mac on Arm64 chip and get a warning that the docker container was meant for Linux/x86-64, you can ignore it. Sending errors to bit bucket.

docker run -d --network yb-net --name yb-america -p5001:5433 -p7001:7000 -p7101:7100 -p9001:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --listen yb-america \
 --master_flags="placement_zone=1,placement_region=america,placement_cloud=cloud" \
 --tserver_flags="placement_zone=1,placement_region=america,placement_cloud=cloud"  2>/dev/null

echo "\n Watch the cluster config 127.0.0.1:7001 after every container starts up after 20 seconds. 
As the first node creates the cluster, from http://localhost:7001/, # of Tserver = 1, Master =1, RF = 1. \n Will wait 20 seconds first...."

sleep 20
echo "Listing all masters \n";  yb-admin -master_addresses localhost:7101   list_all_masters         ; echo 
echo "Listing all tservers \n" ; yb-admin -master_addresses localhost:7101, list_all_tablet_servers  ; echo
echo "Listing replication factor \n" ; lynx localhost:7001 -dump | grep "Replication" | awk '{print $1,$2,$3}'

pause

# At this stage, if you want you can create a table

echo "\n Now with just one node in the cluster, creating a test table. \n And notice that it has only one tablet. It will always have a single tablet as we add nodes.\n"

ysqlsh -p 5001 -U yugabyte -ec "create table t1 ( c1 int ) " ;
echo "\nChecking tablets for table t1 \n";  yb-admin -master_addresses localhost:7101 list_tablets ysql.yugabyte t1

pause

echo "\n Now we will add the 2nd node/continent - Africa \n"

docker run -d --network yb-net --name yb-africa -p5002:5433 -p7002:7000 -p7102:7100 -p9002:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --listen yb-africa --join yb-america \
 --master_flags="placement_zone=1,placement_region=africa,placement_cloud=cloud" \
 --tserver_flags="placement_zone=1,placement_region=africa,placement_cloud=cloud"  2>/dev/null

#  docker run -d --network yb-net --name yb-america -p5001:5433 -p7001:7000 -p9001:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --advertise_address=127.0.0.1


echo "\n As the 2nd node joins the cluster, from http://localhost:7001/,  # of Tserver = 2, Master =2, RF = 1. \n Waiting 20 seconds..."

sleep 20
echo "Listing all masters \n";  yb-admin -master_addresses localhost:7101,localhost:7102 list_all_masters        ; echo 
echo "Listing all tservers \n"; yb-admin -master_addresses localhost:7101,localhost:7102 list_all_tablet_servers ; echo
echo "Listing replication factor \n" ; lynx localhost:7001 -dump | grep "Replication" | awk '{print $1,$2,$3}'

pause

echo "\n Now with 2 nodes in the cluster, creating 2nd test table after 20 seconds - this time will connect to the 2nd node after 20 seconds \n
In addition please note that the # of tablets per table is 1 for t1 and 2 for t2\n"

ysqlsh -p 5002 -U yugabyte -ec "create table t2 ( c1 int ) " ;
echo "\nChecking tablets for table t1 \n"; yb-admin -master_addresses localhost:7101,localhost:7102 list_tablets ysql.yugabyte t1
echo "\nChecking tablets for table t2 \n"; yb-admin -master_addresses localhost:7101,localhost:7102 list_tablets ysql.yugabyte t2

pause

echo "\n Now we add a third continent, Europe"

docker run -d --network yb-net --name yb-europe -p5003:5433 -p7003:7000 -p7103:7100 -p9003:9000 yugabytedb/yugabyte:$version yugabyted start --daemon=false --listen yb-europe --join yb-america \
 --master_flags="placement_zone=1,placement_region=europe,placement_cloud=cloud" \
 --tserver_flags="placement_zone=1,placement_region=europe,placement_cloud=cloud"  2>/dev/null

echo "\n When all 3 nodes are added, watch that the  number of Tserver = 3, Master =3, RF = 3. RF jumped from 1 to 3. 
However if you see the full config of the cluster, the default cloud, region and zone is cloud1, datacenter1, rack1 respectively. 
Our region, cloud are different. This even though the RF number is 3 when we try to create a table it will fail. \n"

sleep 20
echo "Listing all masters \n";   yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_all_masters        ; echo
echo "Listing all tservers \n" ; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_all_tablet_servers ; echo
echo "Listing replication factor \n" ; lynx localhost:7001 -dump | grep "Replication" | awk '{print $1,$2,$3}'

echo "\n Creating 3rd test table - this time will connect to the 3rd node - it will fail as placement is invalid. Again wait 20 seconds first"

ysqlsh -p 5003 -U yugabyte -ec "create table t3 ( c1 int ) " ;

echo "\n Let's fix the placement issue \n"

pause

yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 modify_placement_info cloud.am.1:1,cloud.af.1:1,cloud.eu.1:1 3

echo "\n Now with 3 nodes in the cluster, placement modified, creating 3rd test table - this time will connect to the 3rd node - it will succeed" 

pause

ysqlsh -p 5003 -U yugabyte -ec "create table t3 ( c1 int ) " ;

echo "\n Watch that the number of tablets for table t1 is 1, for t2 2, and for t3 3  at localhost:9001/tables \n"
echo "\nChecking tablets for table t1 \n"; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_tablets ysql.yugabyte t1
echo "\nChecking tablets for table t2 \n"; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_tablets ysql.yugabyte t2
echo "\nChecking tablets for table t3 \n"; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_tablets ysql.yugabyte t3

 # Add two more nodes to the cluster - 

 echo "\n Adding a 4th node to the cluster - Asia \n"

pause

docker run -d --network yb-net --name yb-asia -p5004:5433 -p7004:7000 -p7104:7100 -p9004:9000 yugabytedb/yugabyte:$version \
yugabyted start --daemon=false --listen yb-asia --join yb-america \
 --master_flags="placement_zone=1,placement_region=asia,placement_cloud=cloud" \
--tserver_flags="placement_zone=1,placement_region=asia,placement_cloud=cloud"  2>/dev/null

echo "\n As the 4th node joins the cluster, from http://localhost:7001/,  # of Tserver = 4, Master =3, RF = 3. \n Waiting 20 seconds..."

sleep 20
echo "Listing all masters \n";   yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_all_masters        ; echo
echo "Listing all tservers \n" ; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_all_tablet_servers ; echo
echo "Listing replication factor \n" ; lynx localhost:7001 -dump | grep "Replication" | awk '{print $1,$2,$3}'

pause
#sleep 15 Without a pause, put a wait - so that the new node can join the cluster

echo "\n Adding a 5th node to the cluster - Australia \n"

pause

docker run -d --network yb-net --name yb-australia -p5005:5433 -p7005:7000 -p7105:7100 -p9005:9000 yugabytedb/yugabyte:$version \
yugabyted start --daemon=false --listen yb-australia --join yb-america \
 --master_flags="placement_zone=1,placement_region=australia,placement_cloud=cloud" \
--tserver_flags="placement_zone=1,placement_region=australia,placement_cloud=cloud"  2>/dev/null

echo "\n As the 5th node joins the cluster, from http://localhost:7001/,  # of Tserver = 5, Master =3, RF = 3. \n Waiting 20 seconds..."

sleep 20
echo "Listing all masters \n";   yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_all_masters        ; echo
echo "Listing all tservers \n" ; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_all_tablet_servers ; echo
echo "Listing replication factor \n" ; lynx localhost:7001 -dump | grep "Replication" | awk '{print $1,$2,$3}'

pause

echo "\n By changing the placement information, you can change RF to any number - like RF 4 with 5 tserver nodes - leaving one node Asia out \n"
yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 modify_placement_info cloud.am.1:1,cloud.af.1:1,cloud.eu.1:1,cloud.au.1:1 4
echo "Listing replication factor \n" ; lynx localhost:7001 -dump | grep "Replication" | awk '{print $1,$2,$3}'

# Creating t4 with RF4 fails.. need to investigate - commenting out for now
# echo "\n Now with RF4, create a table t4"
# ysqlsh -p 5004 -U yugabyte -ec "create table t4 ( c1 int ) " ;
# echo "\nChecking tablets for table t4 \n"; 
# yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_tablets ysql.yugabyte t4


pause
echo "\n In addition, it is possible to have RF to any number - and not every node needs to have a copy - here 7 copies leaving one node Australia out"
yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 modify_placement_info cloud.am.1:1,cloud.af.1:2,cloud.eu.1:2,cloud.ap.1:2 7
echo "Listing replication factor \n" ; 
lynx localhost:7001 -dump | grep "Replication" | awk '{print $1,$2,$3}'

echo "\n Notice that as the placement info is changed - it affects the placement of the tablets of all the tables t1, t2, t3 with the number of tablets for them still being 1,2,3 respectively
In case you want individual tables to over-ride the cluster placement info, for YCQL - modify placement using yb-admin command.
For YSQL - use tablespace with placement and create the table in that tablespace \n"

echo "\nChecking tablets for table t1 \n"; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_tablets ysql.yugabyte t1
echo "\nChecking tablets for table t2 \n"; yb-admin -master_addresses localhost:7101,localhost:7102,localhost:7103 list_tablets ysql.yugabyte t2
echo "\nChecking tablets for table t3 \n";      

echo "\n Thank you that is end of this demo \n"
