#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# TBD
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=4Gi --param VOLUME_CAPACITY=4Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true -n ${GUID}-jenkins

oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=1 -n ${GUID}-jenkins

# Create custom agent container image with skopeo
# TBD
oc new-build -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
# For some reason using new-build does not work, using oc create instead :(
oc new-build --strategy=pipeline --code=${REPO} -e GUID=${GUID} -e REPO=${REPO} -e CLUSTER=${CLUSTER} --context-dir=openshift-tasks --name tasks-pipeline -n ${GUID}-jenkins
# echo "apiVersion: v1
# items:
# - kind: "BuildConfig"
#   apiVersion: "v1"
#   metadata:
#     name: "tasks-pipeline"
#   spec:
#     source:
#       type: "Git"
#       git:
#         uri: ${REPO}
#       contextDir: "openshift-tasks"
#     strategy:
#       type: "JenkinsPipeline"
#       jenkinsPipelineStrategy:
#         jenkinsfilePath: Jenkinsfile
#         env:
#         - name: "GUID"
#           value: ${GUID}
#         - name: "REPO"
#           value: ${REPO}
#         - name: "CLUSTER"
#           value: ${CLUSTER}
#     triggers: []
# kind: List
# metadata: []" | oc create -f - -n ${GUID}-jenkins


# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
