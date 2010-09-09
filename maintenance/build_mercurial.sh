#!/bin/bash

cd ~/src/
cd Python-2.6.2
make clean
./configure
make
sudo make install
cd ../mercurial-fe160ba4c976/
python2.6 setup.py build
sudo python2.6 setup.py install
