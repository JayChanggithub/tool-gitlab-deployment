#!/bin/bash
BLUE="\033[1;34m"
YELLOW="\033[0;33m"
NC1="\033[0m"
flag=$1
wechat_api='http://10.99.104.251:1990/api/v1/wechat-bot/release'

function chkReqs
{
    if [ ! -f README.md ]; then
        echo "README.md not found"
        exit 1
    elif [ "$(command -v curl 2> /dev/null)" == "" ]; then
        echo "'curl' command not found."
        exit 1
    fi
}

function main
{
    chkReqs
    echo -e "${BLUE}
===========================================================================${NC1}
${YELLOW}Notice:
1. Only run the stage if currently build is tagged for release's stage.
2. This stage will release current project via mail API function.
3. It will using 'curl' command that contains arguments for sending E-mail
   to all recipients.${NC1}
${BLUE}===========================================================================${NC1}"

    echo
    relase_ver=$(grep -E '^`Rev: .*`$' README.md \
                      | awk '{print $NF}' \
                      | grep -oE '^([0-9]+\.){2}[0-9]+')
    commit_msg="$(echo $CI_COMMIT_MESSAGE \
                       | grep -oE '\ [0-9](\.|\.\ +).*(\.|。)\ ' \
                       | sed -E 's,(\.|。)\ ,\.__,g' \
                       | sed -E 's,^ | $,,g')"
    recipients=$(for e in `echo "$SIT_RECIPIENTS" \
                                | sed 's,\;, ,g'`; do echo "'$e', "; done)
    cc_recipients=$(for e in `echo "$SIT_RECIPIENTS_CC" \
                                   | sed 's,\;, ,g'`; do echo "'$e', "; done)

     echo -e "${BLUE}
===========================================================================${NC1}
${YELLOW}Release Version: $relase_ver
Recipients:
    - [$recipients]
CC Recipients:
    - [$cc_recipients]
Commit Messages:
    - $CI_COMMIT_MESSAGE${NC1}
${BLUE}===========================================================================${NC1}"

    curl -s ${FLASK_API}/download/storage/$reference -o $reference

    if [ $(grep -c 'file not found.' $reference) -ne 0 ]; then
        curl -s \
             -X POST \
             -F "file=@README.md" \
             -F \
             "mail={'subject': '$CI_PROJECT_NAME $relase_ver Released', 'recipients': [$recipients], 'cc': [$cc_recipients], 'CI_PROJECT_URL': '$CI_PROJECT_URL', 'CI_COMMIT_MESSAGE': '$commit_msg', 'artifacts': '${CI_JOB_URL}/artifacts/download', 'CI_JOB_ID': '$CI_JOB_ID', 'CI_PIPELINE_URL': '$CI_PIPELINE_URL'}" \
             ${FLASK_API}/mail/release
    else
        curl -s \
             -X POST \
             -F "file=@README.md" \
             -F "reference=@$reference" \
             -F \
             "mail={'subject': '$CI_PROJECT_NAME $relase_ver Released', 'recipients': [$recipients], 'cc': [$cc_recipients], 'CI_PROJECT_URL': '$CI_PROJECT_URL', 'CI_COMMIT_MESSAGE': '$commit_msg', 'artifacts': '${CI_JOB_URL}/artifacts/download', 'CI_JOB_ID': '$CI_JOB_ID', 'CI_PIPELINE_URL': '$CI_PIPELINE_URL'}" \
             ${FLASK_API}/mail/release
        if [ "$flag" == "True" ]; then
            curl -s \
                 -X GET \
                 --globoff \
                 "${wechat_api}?script_name=${CI_PROJECT_NAME}&script_version=${relase_ver}&script_commit=`python2.7 -c "import urllib; print urllib.quote_plus('$commit_msg')"`"

        fi
    fi
    echo -e "\nSend $CI_PROJECT_NAME version $relase_ver mail notification."
}

# main
main
