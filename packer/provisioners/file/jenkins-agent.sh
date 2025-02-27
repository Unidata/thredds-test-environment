#!/usr/bin/env bash

JENKINS_JAVA_BIN="/usr/thredds-test-environment/temurin21/bin/java"
JENKINS_AGENT_FILE="/home/jenkins/agent.jar"
JENKINS_WEB_SOCKET=true
JENKINS_AGENT_WORKDIR="/home/jenkins/workspace"

# copied from https://github.com/jenkinsci/docker-agent/blob/master/jenkins-agent
# modified above these lines to to use custom image settings

# The MIT License
#
#  Copyright (c) 2015-2020, CloudBees, Inc.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

# Usage jenkins-agent.sh [options] -url http://jenkins -secret [SECRET] -name [AGENT_NAME]
# Optional environment variables :
# * JENKINS_JAVA_BIN : Java executable to use instead of the default in PATH or obtained from JAVA_HOME
# * JENKINS_JAVA_OPTS : Java Options to use for the remoting process, otherwise obtained from JAVA_OPTS
# * JENKINS_AGENT_FILE : Jenkins agent jar file location, /usr/share/jenkins/agent.jar will be used if this is not set
# * REMOTING_OPTS : Generic way to pass additional CLI options to agent.jar (see -help)
#
# Deprecated environment variables (prefer setting REMOTING_OPTS)
# * JENKINS_TUNNEL : HOST:PORT for a tunnel to route TCP traffic to jenkins host, when jenkins can't be directly accessed over network
# * JENKINS_URL : alternate jenkins URL
# * JENKINS_SECRET : agent secret, if not set as an argument
# * JENKINS_AGENT_NAME : agent name, if not set as an argument
# * JENKINS_AGENT_WORKDIR : agent work directory, if not set by optional parameter -workDir
# * JENKINS_WEB_SOCKET: true if the connection should be made via WebSocket rather than TCP
# * JENKINS_DIRECT_CONNECTION: Connect directly to this TCP agent port, skipping the HTTP(S) connection parameter download.
#                              Value: "<HOST>:<PORT>"
# * JENKINS_INSTANCE_IDENTITY: The base64 encoded InstanceIdentity byte array of the Jenkins controller. When this is set,
#                              the agent skips connecting to an HTTP(S) port for connection info.
# * JENKINS_PROTOCOLS:         Specify the remoting protocols to attempt when instanceIdentity is provided.

if [ $# -eq 1 ] && [ "${1#-}" = "$1" ] ; then

	# if `docker run` only has one arguments and it is not an option as `-help`, we assume user is running alternate command like `bash` to inspect the image
	exec "$@"

else

	# if -tunnel is not provided, try env vars
	case "$@" in
		*"-tunnel "*) ;;
		*)
		if [ ! -z "$JENKINS_TUNNEL" ]; then
			TUNNEL="-tunnel $JENKINS_TUNNEL"
		fi ;;
	esac

	# if -workDir is not provided, try env vars
	if [ ! -z "$JENKINS_AGENT_WORKDIR" ]; then
		case "$@" in
			*"-workDir"*) echo "Warning: Work directory is defined twice in command-line arguments and the environment variable" ;;
			*)
			WORKDIR="-workDir $JENKINS_AGENT_WORKDIR" ;;
		esac
	fi

	if [ -n "$JENKINS_URL" ]; then
		URL="-url $JENKINS_URL"
	fi

	if [ -n "$JENKINS_NAME" ]; then
		JENKINS_AGENT_NAME="$JENKINS_NAME"
	fi

	if [ "$JENKINS_WEB_SOCKET" = true ]; then
		WEB_SOCKET=-webSocket
	fi

	if [ -n "$JENKINS_PROTOCOLS" ]; then
		PROTOCOLS="-protocols $JENKINS_PROTOCOLS"
	fi

	if [ -n "$JENKINS_DIRECT_CONNECTION" ]; then
		DIRECT="-direct $JENKINS_DIRECT_CONNECTION"
	fi

	if [ -n "$JENKINS_INSTANCE_IDENTITY" ]; then
		INSTANCE_IDENTITY="-instanceIdentity $JENKINS_INSTANCE_IDENTITY"
	fi

	if [ "$JENKINS_JAVA_BIN" ]; then
		JAVA_BIN="$JENKINS_JAVA_BIN"
	else
		# if java home is defined, use it
		JAVA_BIN="java"
		if [ "$JAVA_HOME" ]; then
			JAVA_BIN="$JAVA_HOME/bin/java"
		fi
	fi

	if [ "$JENKINS_JAVA_OPTS" ]; then
		JAVA_OPTIONS="$JENKINS_JAVA_OPTS"
	else
		# if JAVA_OPTS is defined, use it
		if [ "$JAVA_OPTS" ]; then
			JAVA_OPTIONS="$JAVA_OPTS"
		fi
	fi

	if [ "$JENKINS_AGENT_FILE" ]; then
		AGENT_FILE="$JENKINS_AGENT_FILE"
	else
		AGENT_FILE="/usr/share/jenkins/agent.jar"
	fi

	# if both required options are defined, do not pass the parameters
	if [ -n "$JENKINS_SECRET" ]; then
		case "$@" in
			*"${JENKINS_SECRET}"*) echo "Warning: SECRET is defined twice in command-line arguments and the environment variable" ;;
			*)
			SECRET="-secret ${JENKINS_SECRET}" ;;
		esac
	fi

	if [ -n "$JENKINS_AGENT_NAME" ]; then
		case "$@" in
			*"${JENKINS_AGENT_NAME}"*) echo "Warning: AGENT_NAME is defined twice in command-line arguments and the environment variable" ;;
			*)
			AGENT_NAME="-name ${JENKINS_AGENT_NAME}" ;;
		esac
	fi

	#TODO: Handle the case when the command-line and Environment variable contain different values.
	#It is fine it blows up for now since it should lead to an error anyway.

        exec $JAVA_BIN $JAVA_OPTIONS -jar $AGENT_FILE $SECRET $AGENT_NAME $TUNNEL $URL $WORKDIR $WEB_SOCKET $DIRECT $PROTOCOLS $INSTANCE_IDENTITY $REMOTING_OPTS "$@"

fi