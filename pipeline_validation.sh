#!/bin/bash

# define global variables
arg_selector=create
arg_env=prod
arg_flags=""
BLUE="\033[1;34m"
YELLOW="\033[0;33m"
CEND="\033[0m"

# only commit ref name master except branchs
if [ "$CI_COMMIT_REF_NAME" != "master" ]; then
    more << EOF

Only commit ref name master could be send requests to SMS,
current ref is: '${CI_COMMIT_REF_NAME}'

Try to remove any SMS tags concerning:
[
    '<Script Management Validation>',
    '<Script Management Readme>',
    '<Script Management Pre-release>',
    '<Update>',
    '<Test>'
]
, then commit again.

EOF
    exit 1
fi

# select tag by commit messages
if [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Update>') -ne 0 ]; then
    arg_selector=update
fi
if [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Test>') -ne 0 ]; then
    arg_env=test
fi
if [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Reject>') -ne 0 ]; then
    arg_flags=reject
fi

# update mission to script management
if [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Script Management Validation>') -ne 0 ]; then
    python tool-gitlab-deployment/pipeline_validation.py \
           $CI_PROJECT_NAME validation 50 $arg_selector $arg_env $arg_flags
elif [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Script Management Readme>') -ne 0 ]; then
    python tool-gitlab-deployment/pipeline_validation.py \
           $CI_PROJECT_NAME readme 80 $arg_selector $arg_env $arg_flags
elif [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Script Management Pre-release>') -ne 0 ]; then
    python tool-gitlab-deployment/pipeline_validation.py \
           $CI_PROJECT_NAME pre-release 90 $arg_selector $arg_env $arg_flags
else
    echo "Current job build is not contains any Script Management relatived tags," \
         "Skip this stage.."
fi

# save archive to db
previous_stage_job=$(( $CI_JOB_ID - 1 ))
echo -e "${BLUE}Save pipeline archivement to NAS and Redis as following info:${CEND}${YELLOW}"
curl -s -X POST -F "project=$CI_PROJECT_NAME" -F "job=$previous_stage_job" ${FLASK_API}/pipeline/report/archive
echo -en "${CEND}"

