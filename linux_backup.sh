#!/bin/bash
# Array of folders
BASHFOLDER=$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# https://linuxconfig.org/how-to-parse-a-json-file-from-linux-command-line-using-jq
# https://stackoverflow.com/a/24943373
input="$1"
jq=$BASHFOLDER/jq
devices_len=$($jq '.options.devices | length' $BASHFOLDER/options.json) # -s -r

folders_txt_file="/home/anon/Utils/LinuxBackup/folders/folders2.txt"
backup_folder="/home/anon/Documents/_BACKUP/"
folder_dist=""
folder_prefix="linux_backup_"
folders_array=()
# FOLDERSTR=""
folder_length=0

function ProgressBar {
# Process data
	let _progress=(${1}*100/${2}*100)/100
	let _done=(${_progress}*4)/10
	let _left=40-$_done
# Build progressbar string lengths
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")

# 1.2 Build progressbar strings and print the ProgressBar line
# 1.2.1 Output example:
# 1.2.1.1 Progress : [########################################] 100%
printf "\rProgress : [${_done// /#}${_left// /-}] ${_progress}%%"

}

folder_date() {
  local dt=$(date '+%d_%m_%Y_%H%M%S');
  echo "$dt"
}

backup_folders() {
  local dt=$(folder_date)
  # Create folder
  # copy folder
  local counter=1
  folder_dist="${backup_folder}${folder_prefix}${dt}"
  local zipped=$($jq -r ".options.zipped | tostring" $BASHFOLDER/options.json)
  local unzipped=$($jq -r ".options.unzipped | tostring" $BASHFOLDER/options.json)
  local include_parent_folders=$($jq -r ".options.include_parent_folders | tostring" $BASHFOLDER/options.json)
  local cp_command="cp -r" 

  echo $folder_dist

  # if [ $zipped = "true" ]; then
  #   echo "zipped"
  # fi

  # if [ $unzipped = "true" ]; then
  #   echo "unzipped"
  # fi

  if [ $include_parent_folders = "true" ]; then
    cp_command+=" --parent" 
  fi

  # echo $cp_command

  echo $zipped
  echo $unzipped

  # exit 0
  if [ $unzipped = "true" ]; then

    echo "truthy"

    mkdir ${folder_dist}

    for url in "${folders_array[@]}"; do
      $cp_command $url $folder_dist
      counter=$(($counter+1))
      ProgressBar ${counter} ${folder_length}
    done
    echo ""

    if [ $zipped = "true" ]; then
      cd ${backup_folder}
      zip -r -qdgds 10m "${folder_dist}.zip" "${folder_prefix}${dt}"  & ProgressBar -mp $$
      rm -rf "${folder_prefix}${dt}"
    fi
  else

    # pwd

    # WORKING
    zip -r ${folder_dist}.zip ${folders_array[*]}
    echo "${folders_array[*]}"
  fi
}

set_array() {
  local counter=0
  for url in $(cat $folders_txt_file); do
    folders_array[${counter}]+=$url
    echo "${counter} ${url}"
    counter=$((${counter}+1))
  done
  folder_length=$((${counter}+1))
} 


init() {
  cd "${BASHFOLDER}"
  # $jq '.options.devices | length' ./options.json
  # $jq '.options.devices[1]' ./options.json
}

set_settings() {
  # i=0
  tmp=$(mktemp) 

  # while ${i} -lt $; do
  #   echo ${i}
  #   i+=1
  # done
  # for i in ; do
  #   echo ${i}
  # done

  # echo "TEST"

  for ((i = 0; i <= (${devices_len} - 1) ; i++)); do
    echo "${i}): " $($jq ".options.devices[${i}].name" "$BASHFOLDER/options.json")
  done



  # echo $devices_len
  read -p 'Select Number For Device: ' device_no
  device_name=$($jq ".options.devices[${device_no}].name" $BASHFOLDER/options.json)
  backup_folder=$($jq -r ".options.devices[${device_no}].backup_dest | tostring" options.json)

  # UPDATE - device
  $jq ".options.device_name = ${device_name}" options.json > "$tmp" && mv "$tmp" options.json
  $jq ".options.device_no = ${device_no}" options.json > "$tmp" && mv "$tmp" options.json
  
  # -r -> raw output
  devices=$($jq -r ".options.devices[${device_no}].backup_options[] | tostring" $BASHFOLDER/options.json)
  # echo ${devices}

  echo "------------"

  local counter=0
  for i in ${devices}; do
    echo "${counter}): " "${i}"
    counter=$((counter+1))
  done

  # Select Backup Folder From List
  read -p 'Select Backup option: ' backup_folder_no
  backup_option=$($jq -r ".options.devices[${device_no}].backup_options[${backup_folder_no}] | tostring" $BASHFOLDER/options.json)

  # UPDATE backup_option
  $jq ".options.backup_option = \"${backup_option}\"" options.json > "$tmp" && mv "$tmp" options.json
  # echo $backup_option

  # UPDATE folder_prefix
  read -p 'Type Folder Prefix: ' folder_prefix
  $jq ".options.folder_prefix = \"${folder_prefix}\"" options.json > "$tmp" && mv "$tmp" options.json

  # UPDATE IS ZIPPED?
  read -p 'Zip folder? (true or false): ' is_zipped
  $jq ".options.zipped = ${is_zipped}" options.json > "$tmp" && mv "$tmp" options.json

  # Produce unzipped as well
  read -p 'Include Parent Folders? (true or false): ' parent_folders
  $jq ".options.include_parent_folders = ${parent_folders}" options.json > "$tmp" && mv "$tmp" options.json

}

get_settings() {
  device_name=$($jq -r ".options.device_name | tostring" $BASHFOLDER/options.json) 
  device_no=$($jq -r ".options.device_no | tostring" $BASHFOLDER/options.json)
  backup_option=$($jq -r ".options.backup_option" $BASHFOLDER/options.json)
  folder_prefix=$($jq -r ".options.folder_prefix" $BASHFOLDER/options.json)
  backup_folder=$($jq -r ".options.devices[${device_no}].backup_dest | tostring" $BASHFOLDER/options.json)

  # echo $device
  # echo $backup_option
  if [ "$input" = "set" ] || [ -z "${backup_option}" ] || [ -z "${device_no}" ] || [ -z "${folder_prefix}" ]; then
    set_settings
    # echo "empty"
  fi 

  folders_txt_file="${BASHFOLDER}/folders/${backup_option}"

  echo $backup_folder
}

reset_settings() {
  $jq ".options.device = \"\"" options.json > "$tmp" && mv "$tmp" options.json 
  $jq ".options.backup_option = \"\"" options.json > "$tmp" && mv "$tmp" options.json
}




# WORKING ON
echo $input
if [ "$input" = "set" ]; then
  init
  get_settings
  # echo $folder_prefix
else
  echo "ELSE______"
  init
  get_settings
  set_array
  backup_folders
fi

