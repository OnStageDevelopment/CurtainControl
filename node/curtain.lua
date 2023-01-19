peripheral.find("modem", rednet.open)  --Finds Attached Modem and opens it ready for Rednet.
local motor = peripheral.find("electric_motor") --Defines Motor
json = require "libs/json" --Loads JSON Lib 

-- Startup Assignments
motor.stop() -- Sets motor to 0
h_reverse_speed = "false"
v_reverse_speed = "false"

local function translate_speed(go_type,speed)  --Accounts for the positioning of the motors on the drop pulleys to adjust to negative to achieve same rotation direction
    if go_type == "h" then
        if h_reverse_speed == "true" then
            local new_speed = -speed
            return new_speed
        end
    end
    if go_type == "v" then
        if v_reverse_speed == "true" then
            local new_speed = -speed
            return new_speed
        end
    end

    return speed
end

local function config_reader(config_file)  --Decodes config JSON file and sets variables for program to run
    local todecode = fs.open(config_file, "r").readAll()
    local decoded = json.decode(todecode)
    -- Assigns json info to LUA variables
    node_network = decoded["node_network"]
    node_type = decoded["type"]
    node_id = decoded["id"]
    horizontal_dead_on = decoded["horizontal_dead_on"]
    horizontal_dead_off = decoded["horizontal_dead_off"]
    horizontal_complete_off = decoded["horizontal_complete_off"]

    vertical_dead_in = decoded["vertical_dead_in"]
    vertical_dead_out = decoded["vertical_dead_out"]
    vertical_complete_out = decoded["vertical_complete_out"]
    local hreversed = decoded["horizontal_reversed"]
    local vreversed = decoded["vertical_reversed"]
    default_speed = decoded["default_speed"]
    redstone_side = decoded["redstone"]
    -- Sets reverse variable if needed
    if hreversed == "true" then
        h_reverse_speed = "true"
    end
    if vreversed == "true" then
        v_reverse_speed = "true"
    end
    node_protocol = node_network.."."..node_type
    return "Config Loaded!"
end

local function command_handler(cmd) -- Decodes the rednet message and returns the seperated variables
    local decoded = json.decode(cmd)
    local cmd_id = decoded["id"]
    local cmd_command = decoded["command"]
    local cmd_speed = decoded["speed"]
    local cmd_distance = decoded["distance"]
    return {cmd_id,cmd_command,cmd_speed,cmd_distance}
end

local function command_logic_process(cmd) -- Determins if command is meant for this node
    if cmd == node_id or cmd == "*" then
        return true
    else
        return nil
    end
end

local function move(go_type,amount,direction,gospeed) -- Function to move the drop the correct amount of blocks at speed
    if amount == nil then
        return nil
    end
    if direction == nil then
        return nil
    end
    gospeed = translate_speed(go_type,gospeed)
    if direction == "in" then
        translated_speed = -gospeed
    elseif direction == "out" then
        translated_speed = gospeed
    end
    sleep(motor.translate(amount,translated_speed))
    motor.stop()
end

local function pos_file_util(go_type,cmd,pos) -- Handles writing the new drop position and getting the current drop position
    if go_type == "h" then
        file_path = "h_curr_pos.txt"
    elseif go_type == "v" then
        file_path = "v_curr_pos.txt"
    end

    if cmd == "get" then
        local pos_file = fs.open(file_path,"r")
        local res = tonumber(pos_file.readAll())
        pos_file.close()
        return res
    elseif cmd == "set" then
        local pos_file = fs.open(file_path,"w")
        pos_file.write(pos)
        pos_file.close()
        return true
    else
        return nil
    end
end

local function calc_pos(go_type,wanted_pos) --Calculate how many blocks the node needs to move to get to requested positions
    local current_pos = tonumber(pos_file_util(go_type,"get"))
    if current_pos == wanted_pos then
        direction = "none"
        amt = 0
    end
    if current_pos > wanted_pos then
        direction = "out"
        amt = current_pos-wanted_pos
    elseif current_pos < wanted_pos then
        direction = "in"
        amt = wanted_pos-current_pos
    end

    return {amt,direction}
end

local function check_custom(go_type,custom_pos) --Check if the custom drop height is valid
    if go_type == "h" then
        type_complete_out = horizontal_complete_off
        type_dead_in = horizontal_dead_on
    elseif go_type == "v" then
        type_complete_out = vertical_complete_out
        type_dead_in = vertical_dead_in
    end

    if custom_pos < type_complete_out then
        return nil
    elseif custom_pos > type_dead_in then
        return nil
    else
        return "true"
    end
end

print(config_reader("config.json"))  -- Loads Config
redstone.setOutput(redstone_side,false)
rednet.host(node_protocol,"NODE:"..tostring(node_id)) -- Hosts node on the rednet network for lookup
os.setComputerLabel("ONLINE: "..node_protocol.." as ID: "..node_id)
print("\nNode Running on Protocol: "..node_protocol.."\nAs Node ID: "..tostring(node_id))

-- Node should be ready for commands now
while true do
    local senderId, command, protocol = rednet.receive(node_protocol) -- Waits for Rednet command with the node protocol
    local cmd_res = command_handler(command) -- Decodes JSON info from recieved command
    if command_logic_process(cmd_res[1]) then
        print("New command recieved from: "..senderId)
       
        if cmd_res[3] then
            move_speed = cmd_res[3]
        else
            move_speed = default_speed
        end
        if cmd_res[2] == "h_dead_on" then
            local calcs = calc_pos("h",horizontal_dead_on)
            move("h",calcs[1],calcs[2],move_speed)
            pos_file_util("h","set",horizontal_dead_on)
        elseif cmd_res[2] == "h_dead_off" then
            local calcs = calc_pos("h",horizontal_dead_off)
            move("h",calcs[1],calcs[2],move_speed)
            pos_file_util("h","set",horizontal_dead_off)
        elseif cmd_res[2] == "h_complete_off" then
            local calcs = calc_pos("h",horizontal_complete_off)
            move("h",calcs[1],calcs[2],move_speed)
            pos_file_util("h","set",horizontal_complete_off)
        elseif cmd_res[2] == "v_dead_in" then
            local calcs = calc_pos("v",vertical_dead_in)
            redstone.setOutput(redstone_side,true)
            move("v",calcs[1],calcs[2],move_speed)
            redstone.setOutput(redstone_side,false)
            pos_file_util("v","set",vertical_dead_in)
        elseif cmd_res[2] == "v_dead_out" then
            local calcs = calc_pos("v",vertical_dead_out)
            redstone.setOutput(redstone_side,true)
            move("v",calcs[1],calcs[2],move_speed)
            redstone.setOutput(redstone_side,false)
            pos_file_util("v","set",vertical_dead_out)
        elseif cmd_res[2] == "h_custom" then
            if check_custom("h",cmd_res[4]) == "true" then
                local calcs = calc_pos("h",cmd_res[4])
                move("h",calcs[1],calcs[2],move_speed)
                pos_file_util("h","set",cmd_res[4])
            end
        elseif cmd_res[2] == "v_custom" then
            if check_custom("v",cmd_res[4]) == "true" then
                local calcs = calc_pos("v",cmd_res[4])
                redstone.setOutput(redstone_side,true)
                move("v",calcs[1],calcs[2],move_speed)
                redstone.setOutput(redstone_side,false)
                pos_file_util("v","set",cmd_res[4])
            end
        end 
    end
end

