
function start_prog_cb()
   print("starting program")
   dofile("snidev.lua")
end

print("starting device")

local timer = tmr.create()
print("(waiting...)")
timer:register(5000, tmr.ALARM_SINGLE, start_prog_cb)
timer:start()

