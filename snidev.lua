-- This module shows the number of clients that try to
-- probe the ESP8266 in AP-mode.
--
-- Look for devices nearby and send them to an MQTT-Broker.

require "credentials"

conf = {}
conf.wifi = {
   ssid = credentials.WIFI_SSID,
   password = credentials.WIFI_PASSWORD
}
conf.mqtt = {
   host = "iot.eclipse.org",
   port = 1883,
   topic = "snidev"
}
conf.deepsleep = {
   -- how many ms to wait before sleeping
   time_before_sleep = 60000,
   -- how many us to sleep
   sleeptime = 300000000
}

-- remember probes and clients in this table
clients = {}

function probe_received_cb(T)
   -- check if client already seen
   if clients[T.MAC] == nil then
      clients[T.MAC] = {}
      clients[T.MAC].count = 0
   end

   clients[T.MAC].count = clients[T.MAC].count + 1
   clients[T.MAC].rssi = T.RSSI

   -- count clients seen so far and post them to broker
   count = 0
   for mac,vars in pairs(clients) do
      count = count + 1
      print("mac:"..mac.." count:"..vars.count.." rssi:"..vars.rssi)
      mqtt_client:publish(conf.mqtt.topic..'/probe/'..mac.."/count",
			  vars.count, 1, 1)
      mqtt_client:publish(conf.mqtt.topic..'/probe/'..mac.."/rssi",
			  vars.rssi, 1, 1)
   end
   print("#probes: "..count)

   mqtt_client:publish(conf.mqtt.topic..'/numprobes',
		       --    qos retain
		       count, 1, 1)
end

function got_ip_cb()
   print("connected to wifi with IP "..wifi.sta.getip())
   mqtt_client = mqtt.Client("snidev", 100)
   mqtt_client:connect(conf.mqtt.host, conf.mqtt.port, 0,
		       -- callback when connected to broker
		       mqtt_connected_cb)
end

function mqtt_connected_cb()
   print("connected to mqtt broker")
   mqtt_client:publish(conf.mqtt.topic..'/status', 'connected to mqtt', 1, 1)
   wifi.eventmon.register(wifi.eventmon.AP_PROBEREQRECVED,
			  -- register call back for receiving probes
			  probe_received_cb)
end

-- enter deep sleep mode after timer finishes
-- https://nodemcu.readthedocs.io/en/master/en/modules/node/#nod
function time_elapsed_cb()
   print("entering deep sleep mode")
   msg = 'deep sleep for '..(conf.deepsleep.sleeptime/1000000)..' seconds'
   print(msg)

   mqtt_client:publish(conf.mqtt.topic..'/status', msg , 1, 1)
   -- waiting some time for the message to be published
   local timer = tmr.create()
   --          ms
   timer:alarm(500, tmr.ALARM_SINGLE,
	       function()
		  -- enter deep sleep mode
edsleep
		  node.dsleep(conf.deepsleep.sleeptime)
	       end
   )
end


-- configure station, register call back function after connect
sta_config={}
sta_config.ssid = conf.wifi.ssid
sta_config.pwd = conf.wifi.password
sta_config.got_ip_cb = got_ip_cb

-- start the wifi with the given configuration
wifi.sta.config(sta_config)

-- starting timer to alarm for deep sleep shutdown
local timer = tmr.create()
timer:register(conf.deepsleep.time_before_sleep,
	       tmr.ALARM_SINGLE,
	       time_elapsed_cb)
timer:start()
