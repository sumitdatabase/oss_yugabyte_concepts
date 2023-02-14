for cont in `docker ps -a | tail +2 | awk '{print $NF}' | grep yb-`
do 
 docker stop $cont ; docker rm $cont 
done
