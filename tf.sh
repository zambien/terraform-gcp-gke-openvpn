#!/bin/bash

# don't set -e... we want things to finish and will directly handle errors

usage(){

  printf "\n*** USAGE ***\n\n"

  printf "This command wraps terraform so that you can use an environment and remote state easily.\n"
  printf "It uses a tfvar file which is in the config folder and handles remote state for you.\n"
  printf "Note that if you delete, the remote state will also be deleted SO CLEAN FIRST!\n\n"

  printf "Usage: tf <terraform command string> environment\n"
  printf "Example 1 - Apply the plan for shared-dev:        ./tf.sh apply trp-shared-dev\n"
  printf "Example 2 - Apply the plan for a module:          ./tf.sh apply -target="module.mymodule" trp-shared-dev\n"
  printf "Example 3 - *Clean local of all state:            ./tf.sh clean \n\n"

  printf "* This is necessary when switching between envs.\n\n"
  exit 1
}

getpassword() {
    stty -echo
    CHARCOUNT=0
    while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
    do
        # Enter - accept password
        if [[ $CHAR == $'\0' ]] ; then
            break
        fi
        # Backspace
        if [[ $CHAR == $'\177' ]] ; then
            if [ $CHARCOUNT -gt 0 ] ; then
                CHARCOUNT=$((CHARCOUNT-1))
                PROMPT=$'\b \b'
                proxyPass="${proxyPass%?}"
            else
                PROMPT=''
            fi
        else
            CHARCOUNT=$((CHARCOUNT+1))
            PROMPT='*'
            proxyPass+="$CHAR"
        fi
    done
    stty echo
}

handle_passthru_commands(){
  # certain terraform commands take no arguments
  case "$1" in
    show)
      terraform show && exit 0
    ;;
    graph)
      terraform graph && exit 0
    ;;
    validate)
      terraform validate && exit 0
    ;;
    console)
      terraform console && exit 0
    ;;
    get)
      terraform get && exit 0
    ;;
    version)
      terraform version && exit 0
    ;;
    *)
      return
  esac
}

clean_remote_state(){
  # leave nothing behind
  printf "\nDecoupling current remote and local state...\n"
  printf "... removing local tfstate ...\n"
  rm terraform.tfstate*
  sudo rm -R .terraform
  exit 1
}

safe_remote_state(){

  # source the config file
  echo $1
  source env.tfvars

terraform init \
      -backend-config="bucket=openvpn-terraform-state" \
      -backend-config="path=openvpn/terraform.tfstate" \
      -backend-config="credentials=~/.gcp/terraform-gcp-openvpn.json"

  RESULT=$?

  if [ $RESULT != 0 ]; then
    echo "remote state issue is occurring.. running init again.."

terraform init \
      -backend-config="bucket=openvpn-terraform-state" \
      -backend-config="path=openvpn/terraform.tfstate" \
      -backend-config="credentials=~/.gcp/terraform-gcp-openvpn.json"
  fi
}

if [[ ! -f env.tfvars ]]; then
    echo Enter your preferred kubernetes cluster username :
    read proxyUser

    echo Enter your preferred kubernetes cluster password :
    proxyPass=''
    getpassword

    echo "cluster_master_username=\"$proxyUser\"" > env.tfvars
    echo "cluster_master_password=\"$proxyPass\"" >> env.tfvars

    echo -e "\nCredentials have been saved to env.tfvars.  This file is in .gitignore so no worries...\n"
fi

# invoke  usage
# call usage() function if filename not supplied
[[ $# -eq 0 ]] && usage

handle_passthru_commands $1

CMD="terraform $@ -var-file=env.tfvars"
echo $CMD

if [ $1 == "clean" ]; then
   clean_remote_state
else
   safe_remote_state env.tfvars
fi

# run the command
$CMD