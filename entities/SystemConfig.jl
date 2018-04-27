using FileIO

import JSON, Unmarshal

export SystemConfig, KafkaConfig, BotConfig
export decodeSysConfig, encode, readSystemConfigFile

# Validation regexs
_alphaRegex1 = r"^[a-zA-Z0-9]{1,64}$"
_alphaRegex0 = r"^[a-zA-Z0-9]{0,64}$"

struct KafkaConfig
    ip::String
    port::Int
    rawImageChannelName::String
    statusNotificationChannelName::String
    aprilTagsProcessedChannelName::String
    consumerBlockingMs::Int64
    maxMessagesPerRead::Int64
end

struct BotConfig
    deadZoneNorm::Float64
    maxRotSpeed::Float64
    maxTransSpeed::Float64
    rotNormToRadCoeff::Float64
    transNormToMetersCoeff::Float64
    maxImagesPerPose::Int64
end

mutable struct SystemConfig
    botId::String
    sessionPrefix::String
    sessionId::String

    kafkaConfig::KafkaConfig
    botConfig::BotConfig
end

"""
Returns the system config from the given JSON
"""
function decodeSysConfig(jsonData::String)::SystemConfig
    return Unmarshal.unmarshal(SystemConfig, JSON.parse(jsonData))
end

"""
Returns encoded string for SystemConfig
"""
function encode(systemConfig::SystemConfig)::String
    return JSON.json(systemConfig)
end

"""
Read a config file from filesystem
"""
function readSystemConfigFile(fileName::String)
    try
        # Read the configuration
        f = open(fileName, "r")
        sysConfig = decodeSysConfig(readstring(f))
        close(f)

        # Validation
        # 1. session and bot name cannot contain spaces or special chars because it makes it hard to assign labels in neo4j
        if(!ismatch(_alphaRegex1, sysConfig.botId))
            error("Bot ID is not alphanumeric (without spaces, max 64 chars). Please change the bot ID '$(sysConfig.botId)' in the configuration file '$fileName'.")
        end
        if(!ismatch(_alphaRegex0, sysConfig.sessionPrefix))
            error("Session prefix is not alphanumeric (without spaces, max 64 chars). Please change the session prefix '$(sysConfig.sessionPrefix)' in the configuration file '$fileName'.")
        end
        return sysConfig
    catch e
        error("Could not read system configuration file - $e")
    end
end
