#!/bin/sh

# remove existing running container
sudo docker rm $(sudo docker ps -a | grep packageserver | awk '{print $1}')
