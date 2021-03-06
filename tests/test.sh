#!/bin/sh

set -e

clean() {
	rm -fr fakehome
	rm -f mypub mysec yourpub yoursec
	rm -f double.sig trip.txt warn.txt.enc warn.txt.sig danger.txt
	rm -f error.log
}

clean

mkdir -p fakehome/.reop
../reop -G -p mypub -s mysec -n
../reop -G -i gorilla -p yourpub -s yoursec -n
cp yourpub fakehome/.reop/pubkeyring

cat orig.txt | env HOME=fakehome ../reop -E -s mysec -i gorilla -m - -x - |
	../reop -D -s yoursec -p mypub -m - -x - > trip.txt
diff -u orig.txt trip.txt

cat orig.txt | env HOME=fakehome ../reop -Eb -s mysec -i gorilla -m - -x - |
	../reop -D -s yoursec -p mypub -m - -x - > trip.txt
diff -u orig.txt trip.txt

../reop -S -s yoursec -m orig.txt -x - | env HOME=fakehome ../reop -Vq -x - -m orig.txt

env REOP_PASSPHRASE=apples ../reop -Eb -m warn.txt
env REOP_PASSPHRASE=apples ../reop -D -x warn.txt.enc -m danger.txt
diff -u warn.txt danger.txt

env REOP_PASSPHRASE=bananas ../reop -E -m warn.txt
../reop -Se -s mysec -m warn.txt
env REOP_PASSPHRASE=bananas ../reop -D -x warn.txt.enc -m danger.txt
diff -u warn.txt danger.txt
../reop -Vq -p mypub -x warn.txt.sig
../reop -Vq -p yourpub -x warn.txt.sig 2> error.log || true
diff -u expected.log error.log

../reop -Se -s yoursec -m warn.txt.sig -x double.sig
../reop -Vq -p yourpub -x double.sig

echo C passed.

if [ -f ../libreop.so.* ] && luajit -v > /dev/null ; then
	luajit test.lua
else
	echo Skipping lua tests.
fi

if [ -x ../go/reop ] ; then
	../go/reop mysec yourpub warn.txt | ../reop -D -s yoursec -p mypub -x - -m - > danger.txt
	diff -u danger.txt warn.txt
	../go/reop gorilla  warn.txt > warn.txt.enc
	env REOP_PASSPHRASE=gorilla ../reop -D -x warn.txt.enc -m danger.txt
	diff -u danger.txt warn.txt
	echo Go passed.
else
	echo Skipping Go tests.
fi

echo All passed.

clean
