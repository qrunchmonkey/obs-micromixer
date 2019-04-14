------------------------------------------------------------------
-- mixer.lua                                                    --
--                                                              --
-- Copyright (c) 2019 Kris Harris                               --
------------------------------------------------------------------
obs                 = obslua

-- global settings
manage_channels     = {}
trigger_string      = ""

-- constants
MAX_SOURCE_INDEX    = 6

------------------------------------------------------------------
--              scripting api delgate functions
------------------------------------------------------------------

function script_description()
    return "Automatically mute and unmute global audio sources when changing scenes.\n\nMade by SchmuckCo\n\n\n\nSelect which audio sources should be managed:"
end

function script_properties()
    local props = obs.obs_properties_create()
    
    for i = 1,MAX_SOURCE_INDEX do
        local source = obs.obs_get_output_source(i)
        if source ~= nil then
            local name = obs.obs_source_get_name(source)
            obs.obs_properties_add_bool(props, "manage_global_"..i, name)
            obs.obs_source_release(source)
        end

    end

    obs.obs_properties_add_text(props, "trigger_text", "Trigger Text", obs.OBS_TEXT_DEFAULT)

    return props
end

-- A function named script_update will be called when settings are changed and after script_load
function script_update(settings)
    
    trigger_string = obs.obs_data_get_string(settings, "trigger_text")

    manage_channels = {}
    for i = 1,MAX_SOURCE_INDEX do
        local enabled = obs.obs_data_get_bool(settings, "manage_global_"..i)
        if enabled then
            table.insert(manage_channels, i)
        end
    end

end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
    obs.obs_data_set_default_string(settings,"trigger_text", "🔇")

    for i = 1,MAX_SOURCE_INDEX do
        obs.obs_data_set_default_bool(settings, "manage_global_"..i, false)
    end
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
    obs.obs_frontend_add_event_callback(HandleFrontendEvent)
end

------------------------------------------------------------------
--                      uMixer Script
------------------------------------------------------------------


function HandleFrontendEvent(event)
    -- obs.script_log(obs.LOG_INFO, "frontend event=" .. event)

    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        OnSceneChange()
    end
end

function OnSceneChange()
    SetMuteForManagedSources(IsCurrentSceneTagged())
end

function IsCurrentSceneTagged()
    local current_scene = obs.obs_frontend_get_current_scene()
    local scene_name = obs.obs_source_get_name(current_scene)

    obs.obs_source_release(current_scene)

    return string.match(scene_name, trigger_string) ~= nil
end

function SetMuteForManagedSources(muted)
    for _ , source_number in ipairs(manage_channels) do
        local source = obs.obs_get_output_source(source_number)
        obs.obs_source_set_muted(source, muted)
        obs.obs_source_release(source)
    end
end