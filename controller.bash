#! bin/bash

#This script allows you to check if the user enters the correct arguments

#check if the archive file is on the server
function find_archive {
	local answer=$(Send_Msg "find_archive $3")
	if [[ $answer == false ]]; then
		echo -e "File '$3' is not present on the server.\nPlease use the command list to check all the archive files."
		exit 1
	fi
}
#Display the usage
function Usage{
    echo 'Usage : vsh [-start port] [-stop port] [-list localhost port] [-browse localhost port archive_name] [-extract localhost port archive_name]'
    exit 0
}

#Check the arguments and syntax
#$1 Function
#$2 IPHOST
#$3 PORT
#$4 ARCHIVE
function display_usage{
    #check the first argument-the command
    if [[$1 == '-help']]
    then
        Usage
        exit 0
    elif [[$1 == '-start' && $# -ne 2 ]]
    then
        Usage
        exit 0
    elif [[$1 == '-stop' && $# -ne 2 ]]
    then
        Usage
        exit 0
    elif [[$1 == '-list' && $# -ne 3 ]]
    then
        Usage
        exit 0
    elif [[$1 == '-browse' && $# -ne 4 ]] 
    then
        Usage
        exit 0
    elif [[$1 == '-extract' && $# -ne 4 ]] 
    then
        Usage
        exit 0
    fi
    if [[ $1 == '-browse' || $1 == '-extract' ]]; then
		if [[ -z $4 ]]; then
			echo -e "You should specify the archive name."
			exit 1
		else
			find_archive "$2" "$3" "$4"
		fi
	fi
}

function execute{
	if [[ $1 == '-start' ]]; then
		Start_Server "$2"
	elif [[ $1 == '-stop' ]]; then
		Stop_Server "$2"
	else
		case $1 in
			'-browse')
				browse_mode;;
			'-extract')
				extract_mode;;
			'-list')
				show_list;;
			*)
				echo 'Error!'
				exit 1;;
		esac
	fi
}
