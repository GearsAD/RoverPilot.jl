using FileIO

import JSON, Unmarshal
import CloudGraphs

export SystmConfig, KafkaConfig
export decodeSysConfig, encode

struct KafkaConfig
    ip::String
    port::Int
    rawImageChannelName::String
end

struct BotConfig
    deadZoneNorm::Float64
    maxRotSpeed::Float64
    maxTransSpeed::Float64
    rotNormToRadCoeff::Float64
    transNormToMetersCoeff::Float64
    maxImagesPerPose::Float64
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

function readSystemConfigFile(fileName::String)
    # Read the configuration
    f = open(fileName, "r")
    sysConfig = decodeSysConfig(readstring(f))
    close(f)
    return sysConfig
end
