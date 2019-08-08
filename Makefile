.PHONY: test

CONTAINER_NAME=influxdb-test
SHELL=bash

start_influx: stop_influx
	docker run -tid -p 8087:8086 \
	-p 8089:8089/udp \
	-e INFLUXDB_UDP_ENABLED=true \
	-e INFLUXDB_DB=myinflux \
	-e INFLUXDB_HTTP_AUTH_ENABLED=true \
	-e INFLUXDB_ADMIN_ENABLED=true \
	-e INFLUXDB_ADMIN_USER=myuser \
	-e INFLUXDB_ADMIN_PASSWORD=mysecretpassword \
	-v ${PWD}/influxdb-meta.conf:/etc/influxdb/influxdb-meta.conf \
	--name=${CONTAINER_NAME} influxdb -config /etc/influxdb/influxdb-meta.conf

wait-for-influx:
	@echo  "Waiting for InfluxDB: "
	@i=0; while \
		!(curl --fail -i 'http://localhost:8087/ping' >error.log 2>&1 ); do \
		sleep 1; echo -n '.'; \
		if [ $$((i+=1)) -gt 60 ] ; then cat error.log ; exit 1; fi;  \
		done
	@echo "DONE"

stop_influx:
	docker rm -f ${CONTAINER_NAME} || true

test: start_influx wait-for-influx
	MIX_ENV=test mix test ${file}