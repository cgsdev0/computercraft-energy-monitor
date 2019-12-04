print("Starting boot sequence...")
local path = "name"
local version = 1.0
if not fs.exists(path) then
    print("Please create a file called '"..path.."'")
    print("and name your server in it.")
    os.sleep(2)
    return
end
local namefile = fs.open(path, "r")
if not namefile then
    print("Failed to read file "..path)
    os.sleep(2)
    return
end
local server_name = namefile.readLine()
namefile.close()
if not server_name then
    print("Name file was empty, please name your server.")
    os.sleep(2)
    return
end
print("Server name: "..server_name)
local drac = peripheral.find("draconic_rf_storage")
if not drac then
    print("No draconic core found, shutting down.")
    os.sleep(2)
    os.shutdown()
end
print("Draconic storage linked.")
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

local listen_port = 32
local transmit_port = 33

function listenSyn()
    while true do
        local event,
              modemSide,
              senderChannel,
              replyChannel,
              message,
              senderDistance = os.pullEvent("modem_message")
              local recv = textutils.unserialize(message)
              if recv and #recv>2 and recv[1] == "drac_syn" then
                  if version == recv[2] then
                      print("Device "..recv[3].." connected")
                      local response = {"drac_ack", server_name, os.getComputerID()}
                      modem.transmit(replyChannel, listen_port, textutils.serialize(response))
                  else
                      print("Device "..recv[3].." is on a different version")
                      local response = {"drac_vers", version}
                      modem.transmit(replyChannel, listen_port, textutils.serialize(response))
                  end
              end
    end
end

function transmitData()
    local powc = drac.getEnergyStored()
    while true do
        local powl = powc;
        powc = drac.getEnergyStored()
        local used = -(powl-powc)/20
        local msg = {"drac_data", os.getComputerID(), used, powc }
        modem.transmit(transmit_port, listen_port, textutils.serialize(msg))
        os.sleep(1)
    end
end

modem.open(transmit_port)
modem.open(listen_port)
if activator then
    redstone.setOutput(aSide, true)
end
parallel.waitForAll(listenSyn, transmitData)
