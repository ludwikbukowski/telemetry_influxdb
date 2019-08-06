.PHONY: test real_test

CONTAINER_NAME=influxdb-test
SHELL=bash

start_influx: stop_influx
	mkdir -p influxdata
	docker run -tid -p 8089:8086 \
	-e INFLUXDB_DB=myinflux \
	-e INFLUXDB_HTTP_AUTH_ENABLED=true \
	-e INFLUXDB_ADMIN_ENABLED=true \
	-e INFLUXDB_ADMIN_USER=myuser \
	-e INFLUXDB_ADMIN_PASSWORD=mysecretpassword \
	-v ${PWD}/influxdata:/var/lib/influxdb \
	--name=${CONTAINER_NAME} influxdb

wait-for-influx:
	@echo  "Waiting for InfluxDB: "
	@i=0; while \
		!(curl --fail -i 'http://localhost:8089/ping' >error.log 2>&1 ); do \
		sleep 1; echo -n '.'; \
		if [ $$((i+=1)) -gt 60 ] ; then cat error.log ; exit 1; fi;  \
		done
	@echo "DONE"

stop_influx:
	rm -rf influxdata || true
	docker rm -f ${CONTAINER_NAME} || true

test: start_influx wait-for-influx
	MIX_ENV=real_test mix test