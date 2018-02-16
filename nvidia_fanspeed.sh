#!/bin/sh

# interval in seconds for checking temps
INTERVAL=3.0

MINSPEED=30

# temps and fanspeed settings
TEMP[0]=50
SPEED[0]=40

TEMP[1]=60
SPEED[1]=55

TEMP[2]=70
SPEED[2]=75

TEMP[3]=80
SPEED[3]=100

SHOWMAP=${SHOWMAP:-false}

SHOWCURRENT=${SHOWCURRENT:-false}

SAFESPEED=${SPEED[1]}

declare -A PAIRS
for PAIR in 0:1 1:2 2:3; do
    LOW=$(echo "$PAIR" | cut -d: -f1)
    HIGH=$(echo "$PAIR" | cut -d: -f2)
    TDIFF0=$(($((${SPEED[$HIGH]} - ${SPEED[$LOW]})) / $((${TEMP[$HIGH]} - ${TEMP[$LOW]}))))
    TDIFF1=$(($TDIFF0 + ${SPEED[$LOW]}))
    for i in $(seq ${TEMP[$LOW]} ${TEMP[$HIGH]}); do
        if [[ $i == ${TEMP[$LOW]} ]]; then
            PAIRS[$i]=${SPEED[$LOW]}
        elif [[ $i == ${TEMP[$HIGH]} ]]; then
            PAIRS[$i]=${SPEED[$HIGH]}
        elif [[ $TDIFF1 -le ${SPEED[$LOW]} ]]; then
            PAIRS[$i]=${SPEED[$LOW]}
        elif [[ $TDIFF1 -ge ${SPEED[$HIGH]} ]]; then
            PAIRS[$i]=${SPEED[$HIGH]}
        else
            PAIRS[$i]=$TDIFF1
        fi
        TDIFF1=$(($TDIFF1 + $TDIFF0))
    done
done

if [[ $SHOWMAP == true ]]; then
    for i in "${!PAIRS[@]}"; do
        echo $i ${PAIRS[$i]}
    done | sort -n
    exit
fi

trap restoreautofans SIGHUP SIGINT SIGQUIT SIGFPE SIGKILL SIGTERM

function restoreautofans() {
    nvidia-settings -a "[gpu:0]/GPUFanControlState=1" -a "[fan:0]/GPUTargetFanSpeed=30"
    exit
}

nvidia-settings -a "[gpu:0]/GPUFanControlState=1" -a "[fan:0]/GPUTargetFanSpeed=30"

while [ true ]; do
    CTEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader --id=0)
    if [[ $CTEMP -lt ${TEMP[0]} ]]; then
        SPEED=$MINSPEED
    elif [[ $CTEMP -ge ${TEMP[3]} ]]; then
        SPEED=${SPEED[3]}
    elif [[ ! -z ${PAIRS[$CTEMP]} ]]; then
        SPEED=${PAIRS[$CTEMP]}
    else
        SPEED=$SAFESPEED
    fi
    if [[ $SHOWCURRENT == true ]]; then
        echo "Current Temp: $CTEMP Speed: $SPEED"
    fi
    nvidia-settings -a "[gpu:0]/GPUFanControlState=1" -a "[fan:0]/GPUTargetFanSpeed=$SPEED" > /dev/null
    sleep $INTERVAL
done
