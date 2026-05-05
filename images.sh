#!/bin/bash
#docker rm temp-container
docker pull ghcr.io/vados-dev/nginx-custom-builder/ci:v0.0.2
docker run -it --name temp-container ci:v0.0.2 /bin/sh
docker commit temp-container reg.vados.ru/nginx-rpmbuilder-centos10:v0.0.2
docker push reg.vados.ru/nginx-rpmbuilder-centos10:v0.0.2
#docker push reg.vados.ru/docker-registry-ui:2.6.0
#docker rm temp-container
#docker push reg.vados.ru:5000/docker-registry-ui:257-v1.0
#
#docker pull amster-reg/docker-registry-ui:257v1.2b
#docker run -it --name temp-container amster-reg/docker-registry-ui:257v1.2b /bin/sh
#docker commit temp-container amster-reg/amster-registry-ui:257v1.2b
#docker push amster-reg/amster-registry-ui:257v1.2b
#docker rm temp-container
#docker run -it --name temp-container amster-registry:2.8.3 /bin/sh

#docker push 10.30.30.33/amster-registry:2.8.3

#docker push amster-reg:5000/registry-ui:del.0.1.1

#docker rm temp-container

#docker tag amster/amster-registry:2.8.3 amster-registry:2.8.3

#docker build --progress=plain --no-cache -t reg.vados.ru:5000/amster-registry-ui:v1.2 .

#docker push reg.vados.ru:5000/amster-registry-ui:v1.2

#docker pull reg.vados.ru:5000/amster-registry-ui:v1.2

#docker run -it --name temp-container reg.vados.ru:5000/amster-registry-ui:v1.2 /bin/sh

#docker commit temp-container reg.vados.ru:5000/amster-registry-ui:2.5.5v1.3

#docker push reg.vados.ru:5000/amster-registry-ui:2.5.5v1.3
