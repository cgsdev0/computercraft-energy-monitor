local server_name, host_id

local function centerText(text)
    local x,y = term.getSize()
    local x2,y2 = term.getCursorPos()
    term.setCursorPos(math.ceil((x / 2) - (text:len() / 2)), y2)
    print(text)
end

print("Starting boot sequence...")
local path = "name"
local version = 1.0
local connected = false
if not fs.exists(path) then
    print("Please create a file called '"..path.."'")
    print("and name your device in it.")
    os.sleep(2)
    return
end
local namefile = fs.open(path, "r")
if not namefile then
    print("Failed to read file "..path)
    os.sleep(2)
    return
end
local device_name = namefile.readLine()
namefile.close()
if not device_name then
    print("Name file was empty, please name your device.")
    os.sleep(2)
    return
end
print("Device name: "..device_name)
local sides = rs.getSides()
local modem, activator
local mSide, aSide
for i=1,#sides do
    if peripheral.isPresent(sides[i]) then
        local t = peripheral.getType(sides[i])
        if t == "tile_thermalexpansion_device_activator_name" then
            aSide = sides[i]
            activator = peripheral.wrap(aSide)
            print("Autonomous Activator detected on "..aSide)
        elseif t == "modem" then
            if peripheral.call(sides[i],"isWireless") then
                mSide = sides[i]
                modem = peripheral.wrap(mSide)
                print("Wireless modem detected on "..mSide)
            end
        end
    end
end
if not modem then
    print("No wireless modem found, shutting down.")
    os.sleep(2)
    os.shutdown()
end
if activator then
    redstone.setOutput(aSide, true)
end
print("Attempting to connect to nearby server...")
math.randomseed(os.time())
local transmit_port = 32
local nonce_port = math.random(1000)+1000
print("Generated nonce: "..tostring(nonce_port))
local listen_port = 33
local timeout
modem.open(transmit_port)
modem.open(listen_port)
modem.open(nonce_port)
local msg = {"drac_syn", version, device_name}
modem.transmit(transmit_port, nonce_port, textutils.serialize(msg))
timeout = os.startTimer(5)
while true do
    local event, p1, p2, p3, p4, p5 = os.pullEvent()
    if event == "timer" then
        print("")
        print("")
        centerText("Timed out")
        os.sleep(2)
        os.shutdown()
    elseif event == "modem_message" then
        local recv = textutils.unserialize(p4)
        if not recv then
            print("Handshake failed with server, try again.")
            os.sleep(2)
            os.shutdown()
        end
        if recv[1] == "drac_vers" then
            print("Version mismatch with server.")
            print("Device version: "..tostring(version))
            print("Server version: "..tostring(recv[2]))
            os.sleep(2)
            return
        elseif recv[1] == "drac_ack" then
            os.cancelTimer(timeout)
            timeout = os.startTimer(5)
            server_name = recv[2]
            host_id = recv[3]
            connected = true
            print("Successfully connected to "..server_name)
            os.sleep(2)
        elseif recv[1] == "drac_data" and connected and recv[2] == host_id then
            os.cancelTimer(timeout)
            timeout = os.startTimer(5)
            term.clear()
            term.setCursorPos(1,5)
            centerText(server_name)
            centerText("---------------")
            centerText("Usage: "..tostring(math.floor(recv[3])).." RF/t")
            local prefix = {"", "k", " Million", " Billion", " Trillion"}
            local pc = 1
            local calculated = recv[4]
            while math.floor(calculated/1000)>0 do
                pc = pc + 1
                calculated = calculated / 1000
            end

            centerText("Stored: "..tostring(math.floor(calculated))..prefix[pc].." RF")
        end
    end
end
