#! bin/bash

######################
#
# CLIENT SIDE
# This script describes all the client-side functions
#
######################

##Send message to the server and wait for response
function Send_Msg{
    local msg
	local line
	while read line; do
		if [[ "$line" == 'END' ]]; then
			break
		else
			msg="$msg$line\n"
		fi
	done < <(netcat "$IPHOST" "$PORT" <<< "$1")
	echo "$(echo -e -n $msg)" # interpret \n but not the last one
}

#list-mode: Display all the archieves lists on the server
function list_mode{
    echo -e "Here is the list of archieves on the server $PORT \n $(Send_Msg 'show_list')"
}

#browse-mode: use ls/cat/cd/rm/pwd to browse an archive on the server
function browse_mode{
	local previous='/'
	local current='/'
	local command
	local answer
	while [[ $1 != "exit" ]]; do
		echo -n "vsh:$current\$ "
		read command
		set -- $command
		case $1 in
			'archive')
				echo "You are browsing '$ARCHIVE'.";;
			'pwd')
				echo "$current";;
			'ls')
				answer=$(send_msg "$command $current $ARCHIVE")
				if ! [[ -z $answer ]]; then
					echo "$answer"
				fi;;
			'cd')
				answer=$(Send_Msg "$command $current $ARCHIVE $previous")
				if [[ $answer =~ ^/.* ]]; then
					previous="$current"
					current="$answer"
				else echo "$answer"
				fi;;
			'cat')
				answer=$(Send_Msg "$command $current $ARCHIVE")
				if ! [[ -z $answer ]]; then
					echo "$answer"
				fi;;
			'rm')
				answer=$(send_msg "$command $current $ARCHIVE")
				echo "$answer";;
			'clear')
				clear;;
			'exit')
				echo 'Thanks for using!';;
			'extract')
				extract_mode;;
			'help')
				echo -e "archive : Display the current archive.\npwd : display current directory.\nls [path] : display directory content.\ncd [path/-] : change directory.\ncat [file] : Display file content.\nrm [-r] [file/directory] : remove file or directory.\nclear : clean the console.\nexit : exit browse mode.\nextract : extract the current archive.\nswitch [archive] : switch to another archive.";;
			'switch')
				answer=$(Send_Msg "find_archive $2")
				if [[ $answer == false ]]; then
					echo "Archive '$2' does not exist!"
				else
					echo "Switch from '$ARCHIVE' to '$2'."
					ARCHIVE="$2"
					current='/'
					previous='/'
				fi;;
			*)
				answer=$(Send_Msg "$command $current $ARCHIVE")
				if ! [[ -z $answer ]]; then
		    			echo "$answer"
				fi;;
		esac
	done

}

#extract-mode: extract the specified archive on the client computer.
function extract_mode{
	local archive=$(Send_Msg "extract $ARCHIVE")
	local markers=($(echo -e -n "$archive\n" | head -1 | sed -e 's/:/\n/g'))
	local tree=$(echo -e -n "$archive\n" | head -n $((${markers[1]}-1)) | tail -n +${markers[0]})
	local content=$(echo -e -n "$archive\n" | tail -n +${markers[1]})
	local inDirectory=false
	local currentDirectory="./"
	while read -r line; do
		local array=($(echo "$line"))

		if [ "${array[0]}" == "@" ]; then
			inDirectory=false
		fi

		if [ $inDirectory == true ]; then
			if [ "${array[1]:0:1}" == "d" ]; then
				mkdir -p "$currentDirectory/${array[0]}"
			elif [ "${array[1]:0:1}" == "-" ]; then
				if [[ -e "$currentDirectory/${array[0]}" ]]; then
					rm "$currentDirectory/${array[0]}"
				fi
				touch "$currentDirectory/${array[0]}"
				count=1
				( IFS='\n'
				while read -r cLine; do
					if [ $count -ge ${array[3]} ]; then
						if [ $count -le $((${array[3]}+${array[4]}-1)) ]; then
							echo -e -n "$cLine\n" >> $currentDirectory/${array[0]}
						fi
					fi
					count=$(($count+1))
				done <<< "$content" )
			fi

			chmod 000 "$currentDirectory/${array[0]}"
			for i in {1..3}
			do
				chmod u+${array[1]:i:1} "$currentDirectory/${array[0]}"
			done
			for i in {4..6}
			do
				chmod g+${array[1]:i:1} "$currentDirectory/${array[0]}"
			done
			for i in {7..9}
			do
				chmod o+${array[1]:i:1} "$currentDirectory/${array[0]}"
			done
		fi 

		if [ "${array[0]}" == "directory" ]; then
			inDirectory=true
			mkdir -p ${array[1]}
			currentDirectory=${array[1]}
		fi
	done <<< "$tree"
	echo "Archive '$ARCHIVE' has been successfully extracted."
    
}
