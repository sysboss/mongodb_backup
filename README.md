# Automating MongoDB backup to S3 Bucket
This how-to tutorial shows how to automate scheduled backups of Mongo database. The script can store backups on S3 and local copies, according to your requirement. Based on AWS CLI, MongoDump, Tar and Cron.  
Please notice, that this is a very basic way to make sure you do not loose data.  

Key features:
* Fault tolerant
* Stores locally and on S3
* Backups rotation
* Compression

### Getting Started
* Setup a bucket on AWS S3
* Install required packages
  
It's highly recommended to set a lifecycle policy on the bucket to expire files older than X days.  
In my case, I prefer to archive older backups to Glacier, which is much less expensive storage.  

#### Install required packages
On Debian like:
```
# install aws command line
sudo apt install awscli
```

On RedHat like:
```
# install python and pip
sudo yum install epel-release
sudo yum install python python-pip

# install aws command line
sudo pip install --upgrade --user awscli
```

*Outside AWS, make sure you provide proper credentials, using `aws configure` command*

Let's verify we have access to S3. This command will show you all your S3 buckets:
```
aws s3 ls
```

Clone this repository:
```
git clone https://github.com/sysboss/mongodb_backup.git
```

### Usage
```
usage: ./MongoBackup.sh options

OPTIONS:
    -b    AWS S3 Bucket Name
          Bucket to store the backups (eg. db.backups)
          
    -w    Work directory path
          Path to store local copies (see -k flag)
          By default: /home/ubuntu
          
    -n    Instance Name
          Name of MongoDB instance
          By defult: hostname
          
    -l    Log to file Flag
          Will only log to file
          By default: write to STDOUT
          
    -k    Keep local copies
          Number of local copies to keep
          By default: 0
          
    -r    AWS S3 Region (optional)
    
    -p    Path / Folder inside the bucket (optional)
          By default: BucketName/Year/Mon/Day/InstanceName
```

### Automate the backup
To schedule automatic backup at 01:05 AM, add the following line to your crontab:
```
5 1 * * *    ubuntu    /home/ubuntu/MongoBackup.sh -b ${S3-Backups-Bucket} -n ${MongoDB-Server-Name} -k 7

```
*This will upload backups to ${S3-Backups-Bucket} bucket and keep 7 local copies*

### Restore
Steps to restore the database from backup:
1. Download the database snapshot from S3:
```
aws s3 cp --region ${YourRegion} s3://${S3-Backups-Bucket}/${Year}/${Mon}/${Day}/${MongoDB-Server-Name}/mongodump_${timestamp}.tar.gz /tmp
```
2. Decompress the dump:
NOTICE! Make sure you have enough disk space.
```
tar xvfs mongodump_*.tar.gz
```

3. Remove compressed backup tar to free up space
4. Use *mongorestore* utility to restores a binary backup:
```
mongorestore <path to the backup directory>
```
