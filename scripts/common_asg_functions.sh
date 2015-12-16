#!/bin/bash
#
# Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#  http://aws.amazon.com/apache2.0
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

# ELB_LIST defines which Elastic Load Balancers this instance should be part of.
# The elements in ELB_LIST should be seperated by space.
ELB_LIST=""

# Under normal circumstances, you shouldn't need to change anything below this line.
# -----------------------------------------------------------------------------

export PATH="$PATH:/usr/bin:/usr/local/bin"

# If true, all messages will be printed. If false, only fatal errors are printed.
DEBUG=true

# Number of times to check for a resouce to be in the desired state.
WAITER_ATTEMPTS=60

# Number of seconds to wait between attempts for resource to be in a state.
WAITER_INTERVAL=1

# AutoScaling Standby features at minimum require this version to work.
#MIN_CLI_VERSION='1.3.25'
# AutoScaling protection features at minimum require this version to work.
# https://aws.amazon.com/releasenotes/CLI/4500602791571312
MIN_CLI_VERSION='1.9.12'

# Usage: get_instance_region
#
#   Writes to STDOUT the AWS region as known by the local instance.
get_instance_region() {
    if [ -z "$AWS_REGION" ]; then
        AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
            | grep -i region \
            | awk -F\" '{print $4}')
    fi

    echo $AWS_REGION
}

AWS_CLI="aws --region $(get_instance_region)"

# Usage: autoscaling_group_name <EC2 instance ID>
#
#    Prints to STDOUT the name of the AutoScaling group this instance is a part of and returns 0. If
#    it is not part of any groups, then it prints nothing. On error calling autoscaling, returns
#    non-zero.
autoscaling_group_name() {
    local instance_id=$1

    # This operates under the assumption that instances are only ever part of a single ASG.
    local autoscaling_name=$($AWS_CLI autoscaling describe-auto-scaling-instances \
        --instance-ids $instance_id \
        --output text \
        --query AutoScalingInstances[0].AutoScalingGroupName)

    if [ $? != 0 ]; then
        return 1
    elif [ "$autoscaling_name" == "None" ]; then
        echo ""
    else
        echo $autoscaling_name
    fi

    return 0
}

# Usage: autoscaling_set_protected <EC2 instance ID> <ASG name>
#
#   Put <EC2 instance ID> as Protected From Scale In in AutoScaling group <ASG name>. Doing so will
#   prevent it from being terminated.
#
#   Returns 0 if the instance was successfully protected. Non-zero otherwise.
autoscaling_set_protected() {
    local instance_id=$1
    local asg_name=$2

    msg "Checking if this instance has already been put in Protected From Scale In"
    local instance_protected=$(get_instance_protected_state_asg $instance_id)
    if [ $? != 0 ]; then
        msg "Unable to get this instance's protection state."
        return 1
    fi

    if [ "$instance_protected" == "True" ]; then
        msg "Instance is already Protected From Scale In ; nothing to do."
        return 0
    fi

    msg "Putting instance $instance_id as Protected From Scale In"
    $AWS_CLI autoscaling set-instance-protection \
        --instance-ids $instance_id \
        --auto-scaling-group-name $asg_name \
        --protected-from-scale-in
    if [ $? != 0 ]; then
        msg "Failed to put instance $instance_id as Protected From Scale In."
        return 1
    fi

    msg "Waiting for protection to finish"
    wait_for_state "autoscaling_protected" $instance_id "True"
    if [ $? != 0 ]; then
        local wait_timeout=$(($WAITER_INTERVAL * $WAITER_ATTEMPTS))
        msg "Instance $instance_id could not be protected after $wait_timeout seconds"
        return 1
    fi

    return 0
}

# Usage: autoscaling_unset_protected <EC2 instance ID> <ASG name>
#
#   Attempts to remove instance <EC2 instance ID> as Protected From Scale In. Returns 0 if
#   successful.
autoscaling_unset_protected() {
    local instance_id=$1
    local asg_name=$2

    msg "Checking if this instance has already been put out of Protected From Scale In"
    local instance_protected=$(get_instance_protected_state_asg $instance_id)
    if [ $? != 0 ]; then
        msg "Unable to get this instance's protection state."
        return 1
    fi

    if [ "$instance_protected" == "False" ]; then
        msg "Instance is already not Protected From Scale In ; nothing to do."
        return 0
    fi

    msg "Putting instance $instance_id as not Protected From Scale In"
    $AWS_CLI autoscaling set-instance-protection \
        --instance-ids $instance_id \
        --auto-scaling-group-name $asg_name \
        --no-protected-from-scale-in
    if [ $? != 0 ]; then
        msg "Failed to put instance $instance_id as not Protected From Scale In."
        return 1
    fi
    
    msg "Waiting for unprotection to finish"
    wait_for_state "autoscaling_protected" $instance_id "False"
    if [ $? != 0 ]; then
        local wait_timeout=$(($WAITER_INTERVAL * $WAITER_ATTEMPTS))
        msg "Instance $instance_id could not be unprotected after $wait_timeout seconds"
        return 1
    fi
   
    return 0
}

# Usage: get_instance_protected_state_asg <EC2 instance ID>
#
#    Gets the state of the given <EC2 instance ID> as known by the AutoScaling group it's a part of.
#    State is printed to STDOUT and the function returns 0. Otherwise, no output and return is
#    non-zero.
get_instance_protected_state_asg() {
    local instance_id=$1

    local state=$($AWS_CLI autoscaling describe-auto-scaling-instances \
        --instance-ids $instance_id \
        --query "AutoScalingInstances[?InstanceId == \`$instance_id\`].ProtectedFromScaleIn | [0]" \
        --output text)
    if [ $? != 0 ]; then
        return 1
    else
        echo $state
        return 0
    fi
}

reset_waiter_timeout() {
    local elb=$1

    local health_check_values=$($AWS_CLI elb describe-load-balancers \
        --load-balancer-name $elb \
        --query 'LoadBalancerDescriptions[0].HealthCheck.[HealthyThreshold, Interval]' \
        --output text)

    WAITER_ATTEMPTS=$(echo $health_check_values | awk '{print $1}')
    WAITER_INTERVAL=$(echo $health_check_values | awk '{print $2}')
}

# Usage: wait_for_state <service> <EC2 instance ID> <state name> [ELB name]
#
#    Waits for the state of <EC2 instance ID> to be in <state> as seen by <service>. Returns 0 if
#    it successfully made it to that state; non-zero if not. By default, checks $WAITER_ATTEMPTS
#    times, every $WAITER_INTERVAL seconds. If giving an [ELB name] to check under, these are reset
#    to that ELB's HealthThreshold and Interval values.
wait_for_state() {
    local service=$1
    local instance_id=$2
    local state_name=$3
    local elb=$4

    local instance_state_cmd
    if [ "$service" == "autoscaling_protected" ]; then
        instance_state_cmd="get_instance_protected_state_asg $instance_id"
    else
        msg "Cannot wait for instance state; unknown service type, '$service'"
        return 1
    fi

    msg "Checking $WAITER_ATTEMPTS times, every $WAITER_INTERVAL seconds, for instance $instance_id to be in state $state_name"

    local instance_state=$($instance_state_cmd)
    local count=1

    msg "Instance is currently in state: $instance_state"
    while [ "$instance_state" != "$state_name" ]; do
        if [ $count -ge $WAITER_ATTEMPTS ]; then
            local timeout=$(($WAITER_ATTEMPTS * $WAITER_INTERVAL))
            msg "Instance failed to reach state, $state_name within $timeout seconds"
            return 1
        fi

        sleep $WAITER_INTERVAL

        instance_state=$($instance_state_cmd)
        count=$(($count + 1))
        msg "Instance is currently in state: $instance_state"
    done

    return 0
}

# Usage: check_cli_version [version-to-check] [desired version]
#
#   Without any arguments, checks that the installed version of the AWS CLI is at least at version
#   $MIN_CLI_VERSION. Returns non-zero if the version is not high enough.
check_cli_version() {
    if [ -z $1 ]; then
        version=$($AWS_CLI --version 2>&1 | cut -f1 -d' ' | cut -f2 -d/)
    else
        version=$1
    fi

    if [ -z "$2" ]; then
        min_version=$MIN_CLI_VERSION
    else
        min_version=$2
    fi

    x=$(echo $version | cut -f1 -d.)
    y=$(echo $version | cut -f2 -d.)
    z=$(echo $version | cut -f3 -d.)

    min_x=$(echo $min_version | cut -f1 -d.)
    min_y=$(echo $min_version | cut -f2 -d.)
    min_z=$(echo $min_version | cut -f3 -d.)

    msg "Checking minimum required CLI version (${min_version}) against installed version ($version)"

    if [ $x -lt $min_x ]; then
        return 1
    elif [ $y -lt $min_y ]; then
        return 1
    elif [ $y -gt $min_y ]; then
        return 0
    elif [ $z -ge $min_z ]; then
        return 0
    else
        return 1
    fi
}

# Usage: msg <message>
#
#   Writes <message> to STDERR only if $DEBUG is true, otherwise has no effect.
msg() {
    local message=$1
    $DEBUG && echo $message 1>&2
}

# Usage: error_exit <message>
#
#   Writes <message> to STDERR as a "fatal" and immediately exits the currently running script.
error_exit() {
    local message=$1

    echo "[FATAL] $message" 1>&2
    exit 1
}

# Usage: get_instance_id
#
#   Writes to STDOUT the EC2 instance ID for the local instance. Returns non-zero if the local
#   instance metadata URL is inaccessible.
get_instance_id() {
    curl -s http://169.254.169.254/latest/meta-data/instance-id
    return $?
}
