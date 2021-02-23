# myecsfargate
Supportfog ECS Fargate cluster

This example implementation builds an ECS cluster in the Foghorn Supportfog AWS account with an ECS service that deploys to Fargate provisioned capacity.  In order to use, you must supply a terraform tfvars file with the following variables:

```
{
  "ecs_url": "https://index.docker.io/v1/",
  "ecs_username": "<Your Docker Hub or other registry user name>",
  "ecs_password": "<Your Docker Hub or other registry password>",
  "ecs_email": "<Your Docker Hub or other registry email address>"
}

```
