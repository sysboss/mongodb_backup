# Automating MongoDB backup to S3 Bucket
This how-to tutorial shows how to automate scheduled backups of Mongo database instance 
using cron and Amazon S3 to store the backup data.
Please notice, that this is a very basic way to make sure you do not loose data.  

*Compatible and tested with MongoDB v3.4.4 on Ubuntu*

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
