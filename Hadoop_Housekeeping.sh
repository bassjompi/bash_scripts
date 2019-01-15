#!/bin/sh

###   HouseKeeping Hadoop cluster script v1.5  Juan Pablo Yanez Camacho 31-01-2018   #####
###   Added logging and removal of files in the error folders of the /dal/  folder tree and mapr-reduce history folder  October 2018 ####

### initiate logging

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/var/log/hadoop/Housekeeping_$(date +"%b_%d_%Y").log 2>&1
cat /dev/null > /tmp/errorFolders


#### fixing of under replicated blocks ######

su - hdfs  -c "hdfs fsck / | grep 'Under replicated' | cut -d ':' -f 1 | awk -F':' '{print $1}' > /tmp/under_replicated_files"

for hdfsfile in `cat /tmp/under_replicated_files`
do 
	su - hdfs -c "hdfs dfs -setrep 3 ${hdfsfile}"
done


##### Deleting files in Error folders ####

directories=$(hdfs dfs -ls -R  '/dal/*/*/*' | grep 'error/')

for i in $directories;do
        echo $i >> /tmp/errorFolders
done

files_to_delete=$(cat /tmp/errorFolders | grep '/dal/')

for j in $files_to_delete;do
        su - hdfs  -c "hdfs dfs -rm -skipTrash ${j}"
done


##### Delete old map-reduce history logs

year=$(date +'%Y')

su - hdfs -c "hdfs dfs -rm -R  '/mr-history/done/$[ $year -1 ]' 2>/dev/null "

su - hdfs -c "hdfs dfs -ls  '/mr-history/done/${year}' > "/tmp/mr_delete""

mr_delete=$( cat "/tmp/mr_delete" | grep mr-history |  awk '{ print $8 }'  |  cut -f 5 -d '/' )

for h in $mr_delete;do
    if [ $h -lt $(date +"%m") ];then
        su - hdfs -c "hdfs dfs -rm -R "/mr-history/done/${year}/${h}""
    fi
done


### remove audit logs older than a week ##

find /var/log/hadoop/hdfs/ -mtime +5 -name "hdfs-audit.log*"  -exec rm {} \;
find /var/log/hadoop/hdfs/ -mtime +5 -name "hadoop-hdfs-namenode-ue1-hdp-la02p0.accint.co.log*"  -exec rm {} \;
find /var/log/hadoop/hdfs/ -mtime +5 -name "gc.log-*" -exec rm {} \;
find /var/log/hadoop-yarn/yarn -mtime +5 -name "yarn-yarn-resourcemanager-ue1-hdp-la02p0.accint.co.log.*"  -exec rm {} \;
find /var/log/hadoop-yarn/yarn -mtime +5 -name "rm-audit.log*" -exec rm {} \;  
find /var/log/hadoop-mapreduce/mapred -mtime +5 -name "mapred-mapred-historyserver-ue1-hdp-la02p0.accint.co.log.*" -exec rm {} \;


### cleanup
rm -f /tmp/errorFolders
rm -f /tmp/mr_delete
rm -f /tmp/under_replicated_files
find /var/log/hadoop -mtime +30 -name "Housekeeping_*" -exec rm {} \;
