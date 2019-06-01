------------------------------------------------------------------
-- my_name_is_url.lua                                           --
--                                                              --
-- Copyright (c) 2019 Kris Harris                               --
------------------------------------------------------------------
require("lib/monkey_utils")
obs                 = obslua
inspect             = require 'lib.inspect'
-- global settings
replacements        = {}
last_config_path    = nil
-- global variables
error               = nil

------------------------------------------------------------------
--              scripting api delgate functions
------------------------------------------------------------------

function script_description() 
    return "Programatically update Browser Source URLs.\n\nMade by qrunchmonkey"
end

function script_properties()
    local props = obs.obs_properties_create()
    -- print("Doing script props...")
    
    obs.obs_properties_add_path(props, "config_path", "Configuration Path", obs.OBS_PATH_FILE, "JSON Configuration File (*json)", script_path())
    obs.obs_properties_add_button(props, "refresh_button", "Reload Configuration", DoRefreshButtonPressed)

    for _, r in ipairs(replacements) do 
        for _, url_replacement in ipairs(r.replacements) do
            local label = r.pattern .. "?" .. url_replacement.key
            local type = url_replacement.type
            if type == "string" then
                obs.obs_properties_add_text(props, label, label, obs.OBS_TEXT_DEFAULT)
            elseif type == "int" then
                local min, max, step = RangeForReplacementType(url_replacement)
                obs.obs_properties_add_int(props, label, label, min, max, step)
            elseif type == "float" then
                local min, max, step = RangeForReplacementType(url_replacement)
                obs.obs_properties_add_float(props, label, label, min, max, step)
            elseif type == "int_range" then
                local min, max, step = RangeForReplacementType(url_replacement)
                obs.obs_properties_add_int_slider(props, label, label, min, max, step)
            elseif type == "float_range" then
                local min, max, step = RangeForReplacementType(url_replacement)
                obs.obs_properties_add_float_slider(props, label, label, min, max, step)
            elseif type == "menu" then
                local value_type = url_replacement.value_type
                local list_p
                if value_type == "int" then
                    list_p = obs.obs_properties_add_list(props, label, label, obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
                else -- string type
                    list_p = obs.obs_properties_add_list(props, label, label, obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
                end
                
                for idx, val in ipairs(url_replacement.options) do
                    if value_type == "int" then
                        obs.obs_property_list_add_int(list_p, val.name, val.value)
                    else
                        obs.obs_property_list_add_string(list_p, val.name, val.value)
                    end
                end
            end
        end
        if table.getn(r.replacements) then
            obs.obs_properties_add_button(props, "update_" .. r.pattern, "Update " .. r.pattern, DoUpdateButtonPressed)
        end
    end

    return props
end

-- A function named script_update will be called when settings are changed and after script_load
function script_update(settings)
    
    local config_path = obs.obs_data_get_string(settings, "config_path")
    if last_config_path ~= config_path then
        if LoadConfigFile(config_path) then
            last_config_path = config_path
        end
    end

    -- pull values from settings into (replacement table?)
    for _, r in ipairs(replacements) do 
        for _, url_replacement in ipairs(r.replacements) do
            local label = r.pattern .. "?" .. url_replacement.key
            local type = url_replacement.type
            local value
            if type == "string" then
                value = obs.obs_data_get_string(settings, label)
            elseif type == "int" or type == "float" or type == "int_range" or type == "float_range" then
                value = obs.obs_data_get_double(settings, label)
            elseif type == "menu" then
                local value_type = url_replacement.value_type
                if value_type == "int" then
                    value = obs.obs_data_get_int(settings, label)
                else
                    value = obs.obs_data_get_string(settings, label)
                end
            end
            url_replacement.value = value
        end
    end

    if error then
        print("Parsing error: " .. error)
        error = nil
    end

    -- ApplyReplacementsToURL("http://localhost:666/foo/index.tla#foo=bar")

end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)

end


function script_save(settings)

end

-- a function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
    -- unloaded.
end

------------------------------------------------------------------
--                     MyNameIsURL Script
------------------------------------------------------------------

-- returns true on success
DefaultParseErrorString = "Failed to load or parse the configuration file. Please select a valid configuration file."
function LoadConfigFile(path)
    error = nil
    replacements = {}
    if type(path) == "string" and string.len(path) > 0 then
        local conf = obs.obs_data_create_from_json_file(path)
        if conf == nil then
            error = DefaultParseErrorString
            return false
        end -- we parsed the json...
        local urls = obs.obs_data_get_array(conf, "urls")
        obs.obs_data_release(conf)
        if urls == nil then
            error = DefaultParseErrorString
            return false
        end

        for i= 0, obs.obs_data_array_count(urls) - 1 do
            local item = obs.obs_data_array_item(urls, i)
            local item_table = ConfigParseURLData(item)
            obs.obs_data_release(item)
            
            if item_table ~= nil then
                table.insert( replacements, item_table )
            else if error == nil then
                error = DefaultParseErrorString
                return false
            else
                return false
            end

            end
        end
        obs.obs_data_array_release(urls)
    else
        error = "Start by selecting a configuration file"
        return false
    end
    -- print("Loaded Config:\n" .. inspect(replacements))
    return true
end

-- returns a table representing this borrowed url_item (or false, iff parsing fails - also set error string)
function ConfigParseURLData(url_item)
    local tbl = {}
    
    local pattern = obs.obs_data_get_string(url_item, "pattern")
    local replacements_arr = obs.obs_data_get_array(url_item, "replacements")
    local options_obj = obs.obs_data_get_obj(url_item, "options")
    
    if string.len(pattern) < 3 then
        error = "Invalid URL Pattern: " .. pattern
    end

    local replacements = ConfigParseReplacements(replacements_arr)

    obs.obs_data_release(options_obj)
    obs.obs_data_array_release(replacements_arr)

    if error then
        return false
    end

    return {pattern = pattern, replacements = replacements}
end

function ConfigParseReplacements(replacements)
    local replacements_tbl = {}
    for idx = 0, obs.obs_data_array_count(replacements) - 1 do
        local type_shape = {}
        local obj = obs.obs_data_array_item(replacements, idx)
        local key = obs.obs_data_get_string(obj, "key")
        
        local type_str = obs.obs_data_get_string(obj, "type")
        if type_str ~= obs.obs_data_get_default_string(obj, "type") then
            if type_str == "int" or type_str == "integer" then
                type_shape.type = "int"
            elseif type_str == "float" or type_str == "double" or type_str == "number" then
                type_shape.type = "float"
            elseif type_str == "menu" then
                -- menu item type
                local value_type = obs.obs_data_get_string(obj, "valueType") -- valid types are int or string
                if value_type ~= "int" then
                    value_type = "string"
                end

                local value_arr = obs.obs_data_get_array(obj, "options")
                if value_arr then
                    local options_tbl = {}
                    for j = 0, obs.obs_data_array_count(value_arr) - 1 do
                        local obj_value = obs.obs_data_array_item(value_arr, j)
                        local name = obs.obs_data_get_string(obj_value, "name")

                        if value_type == "string" then
                            local value_str = obs.obs_data_get_string(obj_value, "value")
                            if value_str == nil or value_str == "" then
                                value_str = ""
                                print("Warning: '" .. key .. "' has menu item named '" .. name .. "' with no value set")
                            end
                            table.insert( options_tbl, {name = name, value = value_str} )
                        else -- value_type == "int"
                            --could add a check here to set value to index if it's not set?
                            table.insert( options_tbl, {name = name, value = obs.obs_data_get_int(obj_value, "value")} )
                        end

                        obs.obs_data_release(obj_value)
                    end
                    obs.obs_data_array_release(value_arr)
                    type_shape.type = "menu"
                    type_shape.options = options_tbl
                    type_shape.value_type = value_type
                else
                    error = "key: " .. key .. " is a menu type, but has no values."
                end
            elseif type_str == "range" then
                local min = obs.obs_data_get_double(obj, "min")
                local max = obs.obs_data_get_double(obj, "max")
                local step = obs.obs_data_get_double(obj, "step")
                if min > max then
                    error = "key: " .. key .. " has a larger minimum range (" .. min ..") than it's maximum range (" .. max ..")"
                elseif min == max then
                    error = "key: " .. key .. " has maximum equal to minimum"
                else
                    if max - min <= 4 then
                        type_shape.type = "float_range"
                    else
                        type_shape.type = "int_range"
                    end
                    type_shape.range = {min = min, max = max, step = step}
                end
            else
                type_shape.type = "string"
            end
        else
            error = "key: " .. key .. " is missing type information"
        end
    


        obs.obs_data_release(obj)
        if error then
            return
        end
        type_shape.key = key
        table.insert( replacements_tbl, type_shape )
    end
    -- print("Got replacements: " .. inspect(replacements_tbl))
    return replacements_tbl
end


function DoMeaninglessButtonPress(props, p, d)
    obs.script_log(obs.LOG_INFO, "Meaingless Button Was Pressed" .. inspect(props) .. inspect(p) .. inspect(d))
end

function DoRefreshButtonPressed(props, p)
    -- we need to somehow modify props from here?
    -- local prop = obsobs_properties_get(props, "config_path")
    -- obs.obs_property_modified(props,)
    -- obs.obs_property_set_description(p,"Reloading...")
    -- last_config_path = nil
    return true
end

function DoUpdateButtonPressed(props, p)
    -- print("Update button pressed")
    FindAndUpdateBrowserSources()
end


function RangeForReplacementType(url_replacement)
    local type = url_replacement.type
    local min, max, step
    local range_options = url_replacement.range
    if range_options then
        min = url_replacement.range.min
        max = url_replacement.range.max
        step = url_replacement.range.step
    end

    if type == "float" or type == "float_range" then
        if min == nil then
            min = -math.huge
        end
        if max == nil then
            max = math.huge
        end
        if step == nil or step == 0 then
            step = 1
        end
    else
        if min == nil then
            min = -math.pow(2, 31)
        end
        if max == nil then
            max = math.pow(2, 31) -1
        end
        if step == nil or step < 1 then
            step = 1
        else
            step = math.floor( step )
        end
    end
    return min, max, step
end

function SegmentURL(url)
    local q_idx, q_len = string.find(url, "[#?]")
    if q_idx then
        local base_url = string.sub( url, 0, q_idx )
        local q_part = string.sub(url, q_idx + 1)
        return {base_url, q_part}
    else
        return {url}
    end
end

function BaseURL(url)
    local segments = SegmentURL(url)
    return segments[1]
end

function GetReplacementTable(r_item)
    local tbl = {}
    for _, item in ipairs(r_item.replacements) do
        tbl[item.key] = item.value
    end
    return tbl
end

function URLEncodeQueryTable(tbl)
    -- print("Replacement Table: " .. inspect(tbl))

    local str = ""
    for k,v in pairs(tbl) do
        print("encoding pairs.." .. k .. v)
        if string.len(str) > 0 then
            str = str .. '&'
        end
        str = str .. k
        str = str .. '='
        local type = type(v)
        if type == "string" then
            str = str .. urlencode(v)
        elseif type == "number" or type == "boolean" then
            str = str .. (0 + v)
        elseif type == "nil" then
            --ignore silently
        else
            print("Warning: key " .. k .. "has an unexpected replacement of type " .. type)
        end
       
    end
    return str
end

function ApplyReplacementsToURL(url)
    for _, r in ipairs(replacements) do
        local pattern = r.pattern
        local url_segments = SegmentURL(url)
        if string.match( url_segments[1], pattern ) then
            -- print("URL: " .. url .." matches pattern " .. pattern)
            -- print("URL Segments: " .. inspect(url_segments))

            local params = url_param_decode(url_segments[2])
            -- print("parsed params: " .. inspect(params))

            local replace_tbl = GetReplacementTable(r)
            local q_str = URLEncodeQueryTable(replace_tbl)
            -- print("New query string: " .. q_str)
            return url_segments[1] .. q_str
        end
    end
    return false
end

function FindAndUpdateBrowserSources()
    local sources = obs.obs_enum_sources()

    for _, source in ipairs(sources) do
        local source_id = obs.obs_source_get_id(source)
        local name = obs.obs_source_get_name(source)
        if source_id == "browser_source" then
            local source_settings = obs.obs_source_get_settings(source)
            local source_url = obs.obs_data_get_string(source_settings, "url")
            -- print("Browser source named: '" .. name .."' has settings:\n" .. obs.obs_data_get_json(source_settings))
            if source_url then
                local new_url = ApplyReplacementsToURL(source_url)
                
                if new_url then
                    -- print("Got replacement URL: " .. new_url)
                    obs.obs_data_set_string(source_settings, "url", new_url)
                    obs.obs_source_update(source, source_settings)
                end

                obs.obs_data_release(source_settings)
            end
        end
        -- print("Found source named: '" .. name .."' with id: " ..source_id)
    end
    obs.source_list_release(sources)
end