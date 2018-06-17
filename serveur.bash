#! /bin/bash

#################
#
# SERVER SIDE
# This script deals with all the requirements from the client-side
#
#################

## Return the full path
function getFullPath{
	if [[ -z $1 ]]; then
		local path="$2"
	elif [[ $1 =~ ^/.* ]]; then
		local path="$1"
	elif [[ $2 == '/' ]]; then
		local path="/$1"
	else
		local path="$2/$1"
	fi
	# path=$(translate_path "$(sed 's/^\///' <<< "$1")" "$2")
	# if [[ $path == '1' ]]; then
	# 	echo 1
	# 	exit 1
	# fi
	echo "$ROOT$path"	
}

##check if the directory path exists
function checkDir{
	local body=$(head -n 1 "$ARCHIVE"/"$2".arch)
	local -i start=$(cut -d':' -f1 <<< "$body")
	local -i end=$(($(cut -d':' -f2 <<< "$body")-1))
	if [[ -z $(sed -n ${start},${end}p "$ARCHIVE"/"$2".arch  | grep "^directory "$1"[/]*$") ]]; then
		echo false
	else echo true
	fi
}

## Get the full root path of the archive.
# $1 = archive name
function getRootPath {
	OIFS=$IFS
	unset IFS
	local body=$(head -n 1 "$ARCHIVE"/"$1".arch)
	local -i start=$(cut -d':' -f1 <<< "$body")
	local -i end=$(($(cut -d':' -f2 <<< "$body")-1))
	local array=($(sed -n ${start},${end}p "$ARCHIVE"/"$1".arch | grep "^directory " | sed 's/directory //'))
	local root="${array[0]}"
	for element in "${array[@]}"; do
		if [[ "${#element}" -lt "${#root}" ]]; then
			root="$element"
		fi
	done
	echo "$(remove_last_slash "$root")"
	IFS=$OIFS
}

##Return the new current directory
function getNewPathDir {
	OIFS=$IFS
	IFS='/'
	array=($1)
	unset array[${#array[@]}-1]
	for folder in ${array[@]}
	do
		echo -n "$folder/"
	done
	IFS=$OIFS
}

function getNewPathFile {
	OIFS=$IFS
	IFS='/'
	array=($1)
	echo ${array[${#array[@]}-1]}
	IFS=$OIFS
}

# Return the list of folder and file of the specified location.
# $1 = full path
# $2 = current directory
# $3 = archive name
function list_all {
	local body=$(head -n 1 "$ARCHIVE"/"$3".arch)
	local -i start=$(cut -d':' -f1 <<< "$body")
	local -i end=$(($(cut -d':' -f2 <<< "$body")-1))
	start=$(($(sed -n ${start},${end}p "$ARCHIVE"/"$3".arch | grep -n "^directory "$1"[/]*$" | cut -d':' -f1)+start))
	i=0
	while read line; do
		if [[ $line == "@" ]]; then
			break
		else
			array[i]="$line"
			i=$((i+1))
		fi
	done < <(tail -n "+$start" "$ARCHIVE"/"$3".arch)
	i=0
	for element in "${array[@]}"; do
		properties="$(cut -d' ' -f2 <<< "$element")"
		if [[ "${properties:0:1}" == 'd' ]]; then
			result[i]="$(cut -d' ' -f1 <<< "$element")/"
		elif ! [[ -z "$(grep 'x' <<< "$properties")" ]]; then
			result[i]="$(cut -d' ' -f1 <<< "$element")*"
		else result[i]="$(cut -d' ' -f1 <<< "$element")"
		fi
		i=$((i+1))
	done
	echo "${result[@]}"
}
# Return the starting line and ending line of specified file.
# $1 = full path
# $2 = target file
# $3 = archive name
function checkFileLines {
	local body=$(head -n 1 "$ARCHIVE/$3.arch")
	local -i start=$(cut -d':' -f1 <<< "$body")
	local -i end=$(($(cut -d':' -f2 <<< "$body")-1))
	start=$(($(sed -n ${start},${end}p "$ARCHIVE/$3.arch" | grep -n "^directory "$1"[/]*$" | cut -d':' -f1)+start))
	local -i count=$start
	while read line; do
		if [[ "$(cut -d' ' -f1 <<< "$line")" == "$2" ]]; then
			break
		elif [[ "$line" == '@' ]]; then
			echo false
			exit 1
		fi
		count=$((count+1))
	done < <(tail -n "+$start" "$ARCHIVE/$3.arch")
	local properties="$(cut -d' ' -f2 <<< "$line")"
	local lines=""
	if [[ "${properties:0:1}" != 'd' ]]; then
		local -i start_line=$(($(cut -d' ' -f4 <<< "$line")+end))
		local -i length=$(cut -d' ' -f5 <<< "$line")
		local -i end_line=$((start_line+length-1))
		lines="$start_line $end_line $count"
	fi
	if [[ -z $lines ]]; then
		echo false
		exit 1
	elif [[ $length == 0 ]]; then
		echo "0 0 $count 2"
	else echo "$lines"
	fi
}
# Remove a file from an archive.
function removeFile {
	lines=($(checkFileLines "$1" "$2" "$3"))
	if [[ $lines != false ]]; then
		archive=$(cat "$ARCHIVE/$3.arch")
		markers=($(echo -e -n "$archive\n" | head -1 | sed -e 's/:/\n/g'))
		tree=`echo -e -n "$archive\n" | head -n $((${markers[1]}-1)) | tail -n +$((${markers[0]}))`
		minLine=$((${lines[0]}-${markers[1]}+1))
		if [[ $((${lines[1]}-${lines[0]})) -ne 0 ]]; then
			while read -r line; do
				array=($(echo $line))
				if [[ ${#array[@]} -eq 5 ]]; then
					if [[ ${array[3]} -gt $minLine ]]; then
						array[3]=$((${array[3]}-(${lines[1]}-${lines[0]}+1)))
						newLine=$( IFS=" " ; echo "${array[*]}" )
						sed -i "s/$line/$newLine/g" "$ARCHIVE/$3.arch"
					fi
				fi
			done <<< "$tree"
			sed -i "${lines[0]},${lines[1]}d" "$ARCHIVE/$3.arch"
		fi
		echo "${lines[2]}"
	else
		echo false
	fi
}
# Check if the line has to be removed.
function isDeletable {
	if [[ $2 == *$1* ]]; then
		echo true
	else
		echo false
	fi
}
# Ensure that there is no slash at the end of path.
# $1 - the path
function remove_last_slash {
	if [[ $1 != '/' ]]; then
		echo "$(sed 's/\/$//' <<< "$1")"
	else echo "$1"
	fi
}
# Update markers in the header of a specified archive.
function update_markers {
	archive=$(cat "archives/$2.arch")
	markers=($(echo -e -n "$archive\n" | head -1 | sed -e 's/:/\n/g'))
	sed -i "s/${markers[0]}:${markers[1]}/${markers[0]}:$((${markers[1]}-$1))/g" archives/$2.arch
}

# Give an answer to the message from the client
# $1 = command
# $2 = current directory
# $3 = current directory/archive name
# $4 = archive name/previous directory
# $5 = previous directory
function Receive_Msg{
	while read line; do
	set -- $line
	case $1 in
	    'show_list')
            echo "$(ls -p $ARCHIVE | grep -v / | grep '.arch$' | sed 's/.arch$//')";;
		'find_archive')
				if [[ -e "$ARCHIVE"/"$2".arch ]]; then
					echo true
				else echo false
				fi;;
		'ls')
				if [[ $# -eq 4 ]]; then
					local target=$(remove_last_slash "$2")
					local current=$3
					local archive=$4
				elif [[ $# -eq 3 ]]; then
					local target=''
					local current=$2
					local archive=$3
				else echo 'Error.'
				fi
				if [[ $# -eq 4 || $# -eq 3 ]]; then
					ROOT=$(getRootPath "$archive")
					local path=$(getFullPath "$target" "$current" "$archive")
					if [[ $(checkDir "$path" "$archive") == true ]]; then
						echo "$(list_all "$path" "$current" "$archive")"
					else echo "Directory $target not found."
					fi
				fi;;
		'cd')
				if [[ $# -eq 5 ]]; then
					local target=$(remove_last_slash "$2")
					if [[ $target == "-" ]]; then
						echo "$5"
					elif ! [[ $target =~ ^/\.\. ]]; then
						local current=$3
						local archive=$4
						ROOT=$(getRootPath "$archive")
						local path=$(getFullPath "$target" "$current" "$archive")
						if [[ $path == '1' ]]; then
							echo "Error!"
						elif [[ "$(checkDir $path $archive)" == true ]]; then
							echo "$(sed 's,^'"$ROOT"',,' <<< $path)"
						fi
					else echo "/.. can not exist!"
					fi
				else echo 'Error.'
				fi;;
		'cat')
				if [[ $# -eq 4 ]]; then
					local target="$2"
					local current="$3"
					local archive="$4"
					local base=${target##*/}
					if ! [[ -z $base ]]; then
						ROOT=$(getRootPath "$archive")
						local path=$(getFullPath "$target" "$current" "$archive" | sed 's/'"$base"'//')
						path=$(remove_last_slash "$path")
						if [[ $path == '1' ]]; then
							echo "Error!"
						elif [[ "$(checkDir $path $archive)" == true ]]; then
							local lines="$(checkFileLines $path $base $archive)"
							local -i code=$?
							if [[ $(cut -d' ' -f4 <<< "$lines") -eq 2 ]]; then
								echo 'File empty'
							elif [[ $lines == false ]]; then
								echo "File $base not found."
							elif [[ $code -eq 0 ]]; then
								local start_line=$(cut -d' ' -f1 <<< "$lines")
								local end_line=$(cut -d' ' -f2 <<< "$lines")
								echo "$(sed -n ${start_line},${end_line}p "$ARCHIVE"/"$archive".arch)"
							fi
						fi
					else echo "$target: Not a directory"
					fi
				else echo 'Error.'
				fi;;
		'rm')
				if [[ $# == 5 ]]; then
					if [[ $2 == "-r" ]]; then
						local target=$3
						local current=$4
						local archive=$5
						ROOT=$(getRootPath "$archive")
						local path=$(getFullPath "$target" "$current" "$archive")
						if [[ "$(checkDir $path $archive)" == true ]]; then
							local cArchive=$(cat "archives/$archive.arch")
							local markers=($(echo -e -n "$cArchive\n" | head -1 | sed -e 's/:/\n/g'))
							local tree=$(echo -e -n "$cArchive\n" | head -n $((${markers[1]}-1)) | tail -n +${markers[0]})
							local toDelete=false
							local removeDirectory=""
							local nbLine=${markers[0]}
							local nbMarkers=0
							local previousLine=""
							local linesToDelete=()
							while read -r line; do
								local array=($(echo "$line"))
								if [[ ${array[0]} == 'directory' ]]; then
									removeDirectory=${array[1]}
									if [[ "$(isDeletable "$path" "${array[1]}")" == true ]]; then
										toDelete=true
										if [[ $previousLine == "@" ]]; then
											linesToDelete+=("$(($nbLine-1))")
											nbMarkers=$(($nbMarkers+1))
										fi
										linesToDelete+=("$nbLine")
										nbMarkers=$(($nbMarkers+1))
									fi
								elif [[ ${array[0]} == '@' ]]; then
									toDelete=false
								elif [[ $toDelete == true ]]; then
									if [[ ${#array[@]} -eq 3 ]]; then
										linesToDelete+=("$nbLine")
										nbMarkers=$(($nbMarkers+1))
									elif [[ ${#array[@]} -eq 5 ]]; then
										linesToDelete+=($(removeFile "$removeDirectory" "${array[0]}" "$archive"))
										nbMarkers=$(($nbMarkers+1))
									fi
								elif [[ ${#array[@]} -eq 3 ]]; then
									toTest="$removeDirectory${array[0]}"
									if [[ $toTest == $path ]]; then
										linesToDelete+=("$nbLine")
										nbMarkers=$(($nbMarkers+1))
									fi
								fi
								nbLine=$(($nbLine+1))
								previousLine=$line
							done <<< "$tree"
							for ((i=${#linesToDelete[@]}-1; i>=0; i--)); do
								sed -i "${linesToDelete[$i]}d" "archives/$archive.arch"
							done
							update_markers "$nbMarkers" "$archive"
							echo "Directory $target removed."
						else
							echo "Directory $target not found."
						fi
					else
						echo "Unknown option ($2)."
					fi
				elif [[ $# == 4 ]]; then
					local target=$2
					local current=$3
					local archive=$4
					ROOT=$(getRootPath "$archive")
					local fullpath=$(getFullPath "$target" "$current" "$archive")
					local path=$(remove_last_slash "$(getNewPathDir "$fullpath")")
					local file=$(getNewPathFile "$fullpath")
					local linesToDelete=$(removeFile "$path" "$file" "$archive")
					if [[ $linesToDelete -ne false ]]; then
						sed -i "$linesToDelete"d "archives/$archive.arch"
						update_markers "1" "$archive"
						echo "File $file removed."
					else
						echo "File $file not found."
					fi
				fi;;
		    *)
				if [[ $# -gt 2 ]]; then
					echo 'Unknown command.'
				fi;;
		'extract')
				echo "$(cat $ARCHIVE/$2.arch)";;							
	esac
	done	    
}

# Launch another proccess to handle msg from client
ARCHIVE = $1
Receive_Msg
exit 0
