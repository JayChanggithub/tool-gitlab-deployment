#!/bin/bash

# define global variables
arg_selector=create
arg_env=prod

# commit messages tag selector
if [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Update>') -ne 0 ]; then
    arg_selector=update
fi
if [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Test>') -ne 0 ]; then
    arg_env=test
fi

# update mission to script management
if [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Script Management Validation>') -ne 0 ]; then
    python tool-gitlab-deployment/pipeline_validation.py \
           $CI_PROJECT_NAME validation 50 $arg_selector $arg_env
elif [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Script Management Readme>') -ne 0 ]; then
    python tool-gitlab-deployment/pipeline_validation.py \
           $CI_PROJECT_NAME readme 75 $arg_selector $arg_env
elif [ $(echo $CI_COMMIT_MESSAGE | grep -ci '<Script Management Pre-release>') -ne 0 ]; then
    python tool-gitlab-deployment/pipeline_validation.py \
           $CI_PROJECT_NAME pre-release 90 $arg_selector $arg_env
else
    echo "Current job build is not contains any Script Management relatived tags," \
         "Skip this stage.."
fi

