.PHONY: test

CONTAINER_NAME_V1=influxdb-test-v1
CONTAINER_NAME_V2=influxdb-test-v2

SHELL=bash

USERNAME=myuser
PASSWORD=mysecretpassword
STORAGE=myinflux
TOKEN=mysecrettoken

start_influx: start_influx_v1 start_influx_v2

start_influx_v1: stop_influx_v1
	docker run -tid -p 8087:8086 \
	-p 8089:8089/udp \
	-e INFLUXDB_UDP_ENABLED=true \
	-e INFLUXDB_DB=${STORAGE} \
	-e INFLUXDB_HTTP_AUTH_ENABLED=true \
	-e INFLUXDB_ADMIN_ENABLED=true \
	-e INFLUXDB_ADMIN_USER=${USERNAME} \
	-e INFLUXDB_ADMIN_PASSWORD=${PASSWORD} \
	-v ${PWD}/influxdb-meta.conf:/etc/influxdb/influxdb-meta.conf \
	--name=${CONTAINER_NAME_V1} influxdb:1.8 -config /etc/influxdb/influxdb-meta.conf

start_influx_v2: stop_influx_v2
	docker run -tid -p 9999:8086 \
	-e DOCKER_INFLUXDB_INIT_MODE=setup \
	-e DOCKER_INFLUXDB_INIT_USERNAME=${USERNAME} \
	-e DOCKER_INFLUXDB_INIT_PASSWORD=${PASSWORD} \
	-e DOCKER_INFLUXDB_INIT_ORG=myorg \
	-e DOCKER_INFLUXDB_INIT_BUCKET=${STORAGE} \
	-e DOCKER_INFLUXDB_INIT_RETENTION=1w \
	-e DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${TOKEN} \
	--name=${CONTAINER_NAME_V2} influxdb:2.0

wait_for_influx: wait_for_influx_v1 wait_for_influx_v2

wait_for_influx_v1:
	@echo  "Waiting for InfluxDB v1: "
	@i=0; while \
		!(curl --fail -i 'http://localhost:8087/ping' >error_v1.log 2>&1 ); do \
		sleep 1; echo -n '.'; \
		if [ $$((i+=1)) -gt 60 ] ; then cat error_v1.log ; exit 1; fi;  \
		done
	@echo "DONE"

wait_for_influx_v2:
	@echo  "Waiting for InfluxDB v2: "
	@i=0; while \
		!(curl --fail -i 'http://localhost:9999/ping' >error_v2.log 2>&1 ); do \
		sleep 1; echo -n '.'; \
		if [ $$((i+=1)) -gt 60 ] ; then cat error_v2.log ; exit 1; fi;  \
		done
	@echo "DONE"

stop_influx: stop_influx_v1 stop_influx_v2

stop_influx_v1:
	docker rm -f ${CONTAINER_NAME_V1} || true

stop_influx_v2:
	docker rm -f ${CONTAINER_NAME_V2} || true

test: start_influx wait_for_influx
	MIX_ENV=test mix test ${file}
