-- Check if folders and files exist

if not fs.isDir("libs") then
    fs.makeDir("libs")
    print("Created libs Directory")
end
if not fs.exists("h_curr_pos.txt") then
    local file = fs.open("h_curr_pos.txt","w")
    io.write("Please enter current distance: ")
    local distance = io.read()
    file.write(distance)
    file.close()
    print("Created H_CurrentPosition File")
elseif not fs.exists("v_curr_pos.txt") then
    local file = fs.open("v_curr_pos.txt","w")
    io.write("Please enter current height: ")
    local height = io.read()
    file.write(height)
    file.close()
    print("Created V_CurrentPosition File")
end

if not fs.exists("config.json") then
    local file = fs.open("config.json","w")
    io.write("Please enter json file: ")
    local json = io.read()
    file.write(json)
    file.close()
    print("Created Config File")
end

local jsonfile = fs.open("libs/json.lua","w")
local request = http.get("https://raw.githubusercontent.com/OnStageDevelopment/CurtainControl/main/node/libs/json.lua")
jsonfile.write(request.readAll())
jsonfile.close()
request.close()
print("Updated JSON File")

local dropsfile = fs.open("curtain.lua","w")
local request = http.get("https://raw.githubusercontent.com/OnStageDevelopment/CurtainControl/main/node/curtain.lua")
dropsfile.write(request.readAll())
dropsfile.close()
request.close()
print("Updated Drops File")


shell.run("curtain")