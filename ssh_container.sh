#!/bin/sh
ssh root@$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1)