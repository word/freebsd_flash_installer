#!/bin/sh

# test script for controlling front LEDs on ALIX boards.

allon() {
    echo 1 > /dev/led/led1
    echo 1 > /dev/led/led2
    echo 1 > /dev/led/led3
}

alloff() {
    echo 0 > /dev/led/led1
    echo 0 > /dev/led/led2
    echo 0 > /dev/led/led3
}

normal() {
    echo 1 > /dev/led/led1
    echo 0 > /dev/led/led2
    echo 0 > /dev/led/led3
}

strobe() {
    speed=$1
    allon
    sleep $speed
    alloff
    sleep $speed
}

knight_rider() {
    speed=$1
    echo 1 > /dev/led/led1
    sleep $speed
    echo 1 > /dev/led/led2
    sleep $speed
    echo 1 > /dev/led/led3
    sleep $speed
    echo 0 > /dev/led/led1
    sleep $speed
    echo 0 > /dev/led/led2
    sleep $speed
    echo 0 > /dev/led/led3
    sleep $speed
    echo 1 > /dev/led/led3
    sleep $speed
    echo 1 > /dev/led/led2
    sleep $speed
    echo 1 > /dev/led/led1
    sleep $speed
    echo 0 > /dev/led/led3
    sleep $speed
    echo 0 > /dev/led/led2
    sleep $speed
    echo 0 > /dev/led/led1
    sleep $speed
}

led_mix_loop() {
    while true; do
	for nvar in 1 2 3; do
	    strobe $1
	done

	for nvar in 1 2; do
	    knight_rider $1
	done
    done
}

led_strobe_loop() {
    while true; do
	strobe $1
    done
}

led_rider_loop() {
    while true; do
	knight_rider $1
    done
}

#led_mix_loop 0.03
#led_strobe_loop 0.1
led_rider_loop 0.06
