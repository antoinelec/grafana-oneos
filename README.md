This project aims at easily boostrapping a docker-based Grafana install to query Ekinops OneOS devices. This setup includes:
- Grafana + InfluxDB + Telegraf all setup together
- SNMP settings pre-set
- some alerting rules to generate alarms when a device is unavailable or CPU/MEM is too high
- a dashboard with interface load, alarms, probe measurement
This is a first skeleton to be extended further

# Installation

Pull the this repo:
```cmd
git clone git@github.com:antoinelec/grafana-oneos.git
```

Execute the init script, which will create a dummy https certificate and create init files:
```cmd
bash init.sh
```

Launch it:
```cmd
docker compose up -d
```

# Verify Installation

Check containers are up and running. Example:
```bash
root@AP-2DMI7YkhmjZh:~# docker ps | grep -E "(CONTAINER|grafana|influx|telegraf)"
CONTAINER ID   IMAGE                      COMMAND                  CREATED         STATUS                 PORTS                                                                                                                                                                                                                                                                                                             NAMES
bd652b490efa   grafana/grafana:12.4.0     "/run.sh"                2 hours ago     Up 2 hours             0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp                                                                                                                                                                                                                                                                       grafana-github-work-grafana-1
d2917d892f18   telegraf:1.37.3            "/entrypoint.sh tele…"   2 hours ago     Up 2 hours             8092/udp, 8125/udp, 8094/tcp                                                                                                                                                                                                                                                                                      grafana-github-work-telegraf-1
969728912b55   influxdb:2.8.0             "/entrypoint.sh infl…"   2 hours ago     Up 2 hours (healthy)   0.0.0.0:8086->8086/tcp, [::]:8086->8086/tcp                                                                                                                                                                                                                                                                       grafana-github-work-influxdb-1
root@AP-2DMI7YkhmjZh:~#
```

You may want to check logs with:
```cmd
docker compose logs -f grafana
```

# How add a monitored device

This is an example with SNMPv1/v2. In OneOS device, a community should be set:
```cmd
conf t
snmp set-read-community public
end
```

Edit the file telegraf/telegraf.conf. The URL of devices is within that object:
```
  [[inputs.snmp]]
  agents = [ "udp://192.168.56.107:161",
		"udp://192.168.56.108:161",
		"udp://192.168.56.109:161"
             ]

```

Then, restart telegraf to take into account the changes:
```cmd
docker compose restart telegraf
```

