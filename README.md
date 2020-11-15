# cfn-library

[![Build Status](https://travis-ci.org/base2Services/cfn-start-stop-stack.svg?branch=develop)](https://travis-ci.org/base2Services/cfn-start-stop-stack)

## About

Base2Services Common Cloud Formation stacks functionality

## Installation

- As a gem `gem install cfn_manage`

- As a docker container `docker pull base2/cfn-manage`

- Download source code `git clone https://github.com/base2Services/cfn-start-stop-stack`

## Run As Docker Container

Running cfn_manage inside a docker container means you don't have to worry about
managing the runtime environment.

```bash
docker run -ti --rm -v $HOME/.aws/credentials:/root/.aws/credentials base2/cfn-manage
```

You can also pass in additional [Environment Variables](## Environment Variables) using the `-e` flag in the run command

```bash
docker run -ti --rm -v $HOME/.aws/credentials:/root/.aws/credentials -e AWS_REGION=us-east-1 base2/cfn-manage
```

## Functionality

### Stack traversal

Used to traverse through stack and all it's substacks

### Start-stop environment functionality

Stop environment will

- Set all ASG's size to 0
- Stops RDS instances
- If RDS instance is Multi-AZ, it is converted to single-az prior it
  is being stopped
- Disable CloudWatch Alarm actions

Start environment operation will

- Set all ASG's size to what was prior stop operation
- Starts ASG instances
- If ASG instance was Mutli-AZ, it is converted back to Multi-AZ
- Enable CloudWatch Alarm actions
Metadata about environment, such as number of desired/max/min instances within ASG and MultiAZ property
for rds instances, is stored in S3 bucket specified via `--source-bucket` switch or `SOURCE_BUCKET` environment
variable.

Both start and stop environment operations are idempotent, so if you run `stop-environment`
two times in a row, initial configuration of ASG will persist in S3 bucket (rather than storing 0/0/0) as ASG configuration.
Same applies for `start` operation - running it against already running environment won't perform any operations.

In case of some configuration data being lost, script will continue and work with existing data (e.g data about asgs
removed from S3, but rds data persists will results in RDS instances being started)

Order of operations is supported at this point as hardcoded weights per resource type. Pull Requests are welcome
for supporting dynamic discovery of order of execution - local configuration file override is one of
the possible sources.


## Start - stop cloudformation stack

### Supported resources

#### AWS::AutoScaling::AutoScalingGroup

**Stop** operation will set desired capacity of ASG to 0

**Start** operation will restore previous capacity

#### AWS::EC2::Instance

**Stop** operation will stop instance [using StopInstances api call](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_StopInstances.html)

**Start** operation will start instance [using StartInstances api call](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_StartInstances.html)


#### AWS::RDS::DBInstance

**Stop** operation will stop rds instance. Aurora is not supported yet on AWS side. Note that RDS instance can be stopped
for two weeks at maximum. If instance is Multi-AZ, it will get converted to Single-AZ instance, before being stopped
(Amazon does not support stopping Multi-AZ rds instances)


**Start** operation will start rds instance. If instance was running in Multi-AZ mode before being stopped,
it will get converted to Multi-AZ prior being started

#### AWS::DocDB::DBCluster

**Stop** Cluster will be stopped, note that a cluster can only be stopped for a maximum of 7 days, after this time it will turn back on.


**Start** Cluster will be started

#### AWS::CloudWatch::Alarm

**Stop** operation will disable all of alarm's actions

**Start** operation will enable all of alarm's actions

#### AWS::EC2::SpotFleet

**Stop** operation will set spot fleet target to capacity to 0

**Start** operation will restore spot fleet target to capacity to what was set prior the stack being stopped.

#### AWS::ECS::Cluster

**Stop** operation will query all services running in the cluster and set desired capacity to 0

**Start** operation will query all services assocated with the cluster restore desired capacity to what was set prior the stack being stopped.

## CLI usage

You'll find usage of `cfn_manage` within [usage.txt](bin/usage.txt) file

```
Usage: cfn_manage [command] [options]

Commands:

cfn_manage help

cfn_manage version

cfn_manage stop-environment --stack-name [STACK_NAME]

cfn_manage start-environment --stack-name [STACK_NAME]

cfn_manage stop-asg --asg-name [ASG]

cfn_manage start-asg --asg-name [ASG]

cfn_manage stop-rds --rds-instance-id [RDS_INSTANCE_ID]

cfn_manage start-rds --rds-instance-id [RDS_INSTANCE_ID]

cfn_manage stop-aurora-cluster --aurora-cluster-id [AURORA_CLUSTER_ID]

cfn_manage start-aurora-cluster --aurora-cluster-id [AURORA_CLUSTER_ID]

cfn_manage stop-docdb-cluster --docdb-cluster-id [DOCDB_CLUSTER_ID]

cfn_manage start-docdb-cluster --docdb-cluster-id [DOCDB_CLUSTER_ID]

cfn_manage stop-ec2 --ec2-instance-id [EC2_INSTANCE_ID]

cfn_manage start-ec2 --ec2-instance-id [EC2_INSTANCE_ID]

cfn_manage stop-spot-fleet --spot-fleet [SPOT_FLEET]

cfn_manage start-spot-fleet --spot-fleet [SPOT_FLEET]

cfn_manage stop-ecs-cluster --ecs-cluster [ECS_CLUSTER]

cfn_manage start-ecs-cluster --ecs-cluster [ECS_CLUSTER]

cfn_manage disable-alarm --alarm [ALARM]

cfn_manage enable-alarm --alarm [ALARM]

General options:

--source-bucket [BUCKET]

    Pucket used to store / pull information from

--aws-role [ROLE_ARN]

    AWS Role to assume when performing operations. Any reads and
    write to source bucket will be performed outside of this role


-r [AWS_REGION], --region [AWS_REGION]

    AWS Region to use when making API calls

-p [AWS_PROFILE], --profile [AWS_PROFILE]

    AWS Shared profile to use when making API calls

--dry-run

    Applicable only to [start|stop-environment] commands. If dry run is enabled
    info about assets being started / stopped will ne only printed to standard output,
    without any action taken.
    
--debug

    Displays debug logs

--continue-on-error

    Applicable only to [start|stop-environment] commands. If there is problem with stopping a resource,
    (e.g. cloudformation stack not being synced or manual resource deletion) script will continue it's
    operation. By default script stops when there is problem with starting/stopping resource, and expects
    manual intervention to fix the root cause for failure.

--skip-wait

    Skips waiting for resources to achieve stopped or started states.

--wait-async

  Default wait action is to wait for each individual resource to be stopped and started before continuing.
  This will enabled waiting for resources in groups based on priority. Option only useful when used with
  start-environment and stop-environment commands.

--ignore-missing-ecs-config

    This option is required for starting a ecs service that was stopped outside of cfn_manage.

--asg-suspend-termination

    Will stop instances in the autoscaling group(s) instead of the default behaviour of termination.
    
--asg-wait-state
    
    Allowed values ['HealthyInASG','Running','HealthyInTargetGroup']
    Default: 'HealthyInASG'
    
    'HealthyInASG' - waits for all instances to reach a healthy state in the asg
    'Running' - waits for all instances to reach the EC2 running state
    'HealthyInTargetGroup' - waits for all instances to reach a healthy state in all asg assocated target groups

--ecs-wait-state
    
    Allowed values ['Running','HealthyInTargetGroup']
    Default: 'Skip'
    
    'Running' - waits for all ecs services in cluster to reach the running state
    'HealthyInTargetGroup' - waits for all ecs services in cluster to reach a healthy state in all assocated target groups
            
--tags

    will query resource tags for individual resource settings.
        `cfn_manage:priority` for prefered starting order
    will default to defined resource order if no tag is found or resource doesn't support tags
    
--ecs-wait-container-instances
    
    waits for a container instance to be active in the ecs cluster before starting services
```

## Environment Variables

Also, there are some environment variables that control behaviour of the application.
There are command line switch counter parts for all of the

`AWS_ASSUME_ROLE` as env var or `--aws-role` as CLI switch

`AWS_REGION` as env car or `-r`, `--region` as CLI switch

`AWS_PROFILE` as env var or `-p`, `--profile` as CLI switch

`SOURCE_BUCKET` as env var or `--source-bucket` as CLI switch

`DRY_RUN` as env var (set to '1' to enable) or `--dry-run` as CLI switch

`IGNORE_MISSING_ECS_CONFIG` as env var (set to '1' to enable) or `--ignore-missing-ecs-config` as CLI switch

`CFN_CONTINUE_ON_ERROR` as env var (set to '1' to enable) or `--continue-on-error` as CLI switch

`SKIP_WAIT` as env var (set to '1' to enable) or `--skip-wait` as CLI switch

`WAIT_ASYNC` as env var (set to '1' to enable) or `--wait-async` as CLI switch

`ASG_SUSPEND_TERMINATION` as env var (set to '1' to enable) or `--asg-suspend-termination` as CLI switch

`CFN_TAGS` as env var (set to '1' to enable) or `--tags` as CLI switch

`ECS_WAIT_CONTAINER_INSTANCES` as env var (set to '1' to enable) or `--ecs-wait-container-instances` as CLI switch

`CFN_DEBUG` as env var (set to '1' to enable) or `--debug` as CLI switch

## AWS Resource Tags

will query resource tags for individual resource settings. please see bellow the list of resources currently supported by tags and their options.

#### AWS::AutoScaling::AutoScalingGroup'

```yaml
cfn_manage:wait_state: 'HealthyInASG'
cfn_manage:skip_wait: true
cfn_manage:priority: 200
cfn_manage:suspend_termination: true
```

#### AWS::ECS::Cluster

```yaml
cfn_manage:wait_state: 'Running'
cfn_manage:skip_wait: true
cfn_manage:priority: 200
cfn_manage:wait_container_instances: true
cfn_manage:ignore_missing_ecs_config: true
```

## Release process

 - Bump up version `gem install bump && bump [patch|minor|major]`
 - Update timestamp in `cfn_manage.gemspec`
 - Create and publish gem `gem build cfn_manage.gemspec && gem push cfn_manage-$VERSION.gem`
 - Create release page on GitHub
