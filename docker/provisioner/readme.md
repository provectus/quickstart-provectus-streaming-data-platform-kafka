# How to build lambda packages
You have to have pipenv, if you don't have it, please install by 
```sh 
brew install pipenv
```
or
```sh
pip install pipenv
```
Then run create_xxx.sh, it will create zip package that can be uploaded as Lambda package 

# How to deploy 
The Lambda functions deployment handled by CloudFormation templates from "template" directory.
The general logic that you have to build zip lambda packages locally and then upload it to the s3 installation bucket along with CloudFormation templates. 

# How to invoke
Invocation of Lambda function perfoming by CloudFormation Custom Resources. Alternatively you can use Lambda console and create test event, you can find examples of requests body in the subdirectories
