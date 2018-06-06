#! /bin/bash

# Ce script impl�mente un serveur.  
# Le script doit �tre invoqu� avec l'argument :                                                              
# PORT   le port sur lequel le serveur attend ses clients  

if [ $# -ne 1 ]; then
    echo "usage: $(basename $0) PORT"
    exit -1
fi

PORT="$1"

# D�claration du tube

FIFO="/tmp/$US$PORTER-fifo-$$"
FIFO1="/tmp/$USER-fifo-$$-1"


# Il faut d�truire le tube quand le serveur termine pour �viter de
# polluer /tmp.  On utilise pour cela une instruction trap pour �tre sur de
# nettoyer m�me si le serveur est interrompu par un signal.

function nettoyage() { rm -f "$FIFO"; }
trap nettoyage EXIT

# on cr�e le tube nomm�

[ -e "$FIFO" ] || mkfifo "$FIFO"
[ -e "$FIFO1" ] || mkfifo "$FIFO1"


function accept-loop() {
    while true; do
	interaction < "$FIFO" | nc -l  "$PORT" > "$FIFO" 

    done
}

# La fonction interaction lit les commandes du client sur entr�e standard 
# et envoie les r�ponses sur sa sortie standard. 
#
# 	CMD arg1 arg2 ... argn                   
#                     
# alors elle invoque la fonction :
#                                                                            
#         commande-CMD arg1 arg2 ... argn                                      
#                                                                              
# si elle existe; sinon elle envoie une r�ponse d'erreur.                     

function interaction() {
    local cmd args
    while true; do
	read cmd args || exit -1
	fun="commande-$cmd"
	if [ "$(type -t $fun)" = "function" ]; then
	    $fun $args
	else
	    commande-non-comprise $fun $args
	fi
    done
}

# Les fonctions impl�mentant les diff�rentes commandes du serveur


function commande-non-comprise () {
   echo "Le serveur ne peut pas interpr�ter cette commande"
}

function commande-shutdow() {
       shutdown -t 10
}

function commande-convert() {
	echo $args|tr 'a-z' 'A-Z' > /dev/pts/0
	echo $args|tr 'a-z' 'A-Z'

}

function commande-extinction() {
	sleep -s
}






# On accepte et traite les connexions

accept-loop
