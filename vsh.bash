#! bin/bash

##################
#
#This script manages both server/client side
#
##################

source client.sh
source controller.sh

function Main {
	if [[ $1 == "-list" || $1 == "-browse" || $1 == "-extract" ]]; then
		IPHOST=$2
		PORT=$3
		ARCHIVE=$4
	elif [[ $1 == "-start" || $1 == "-stop" ]]; then
		#check if you want to do something with the archives
        if ! [[ -z $3 ]]; 
        then
			ARCHIVE=$3
		else
			ARCHIVE="archives"
		fi
		SCRIPT="serveur.bash $ARCHIVE"
		SERVER="netcat -lp $2 $3" # -e option makes multiples connections possible without broadcasting message to everyone
	fi

	# Check everything
	display_usage "$@"
	#check_config # Disable to avoid cross-platform problem

	# Let's go
	execute "$@"
}


# Launch the server on the specified port
function Start_Server{
if ! [[ -z $(pgrep -lf "$SERVER") ]]; then
		echo "Server is already running on port $1."
		exit 1
	else 
		echo 'Launching server...'
		rm -f /tmp/serverFifo
#		mknod /tmp/serverFifo p
		$SERVER "$SCRIPT" &
		echo "Server is now listening on port $1."
	fi
}

#stop the serve
function Stop_Server{
    local test=$(pgrep -lf "$SERVER" | cut -d' ' -f1)
	if ! [[ -z $test ]]; then
		echo "Stopping server listening on port $1..."
		kill $test
		rm -f /tmp/serverFifo
		echo 'Server stopped!'
	else
		echo "There is no server running on port $1."
		exit 1
	fi
}

main "$@"
exit 0

