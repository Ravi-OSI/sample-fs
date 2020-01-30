# sample-fs
Sample CI setup using github actions to build AWS autoscaling instances backed by loadbalancer, RDS and build/run docker container on provisioned infra.

Scenario :
A new project has just been confirmed within the company. The requirements for the project are modest however due to predicted large amounts of traffic, the solution needs to be hosted in the cloud and scalable. The proposed architecture has the following elements: 
 
● Application 
● SQL Database 
● Load-balancer 
● Auto-scaling

Terraform is used to declare the infra as code in this sample project.

AWS is chosen as cloud provider.

main.tf contains the main code and provisions the below resource

1)	 public and private key pair and registers as aws key_pair to connect to the ec2 which will be provisioned in later steps of the code.
2)	db instance
3)	security group with ingress and egress for loadbalancer
4)	launch configuration for ec2 instances
5)	auto scaling group to create ec2 instances using the provisioned launch config  
6)	elastic load balancer backing the created ec2 instances
7)	null_resource to do the configuration management activities

Note: step 7 will connect to the instances created and uploads the Dockerfile, docker-compose.yml and the test app in bash. It will also build the docker image and run it as background task using docker compose
Terraform.tfvars contains the variables required

Application:
test_pretia.sh: A sample app in bash to read and echo the DB user, password, and endpoint from mounted volume
Dockerfile: copies the app written in bash to the container test directory and uses as entrypoint
docker-compose.yml: builds the image and mounts the secret.txt file which dynamically created during terraform run and contains the DB username, password and the endpoint to connect to db
Note: DB user name and password should be encrypted in github secrets by user, which will be passed to terraform main block as environment variable.

CI/CD:
.github/workflows/terraform.yml : using github actions feature, a workflow is created on every push which will trigger the terraform apply command on main.tf 
Note: main.tf will check the sha of the Dockerfile and will trigger the docker build only if the file is modified.

Conclusion: if the code for infra or the dockerfile or the app is modified and changes are pushed to the master branch, CI setup created in github actions will trigger the workflow which in turn will apply the changes and new instances will be created before the old instances are destroyed so there in no downtime.
