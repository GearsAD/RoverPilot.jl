using Base
using Base.Test

include("../../service/KafkaService.jl")

sysConfig = readSystemConfigFile(dirname(Base.source_path()) *"/../../config/systemconfig.json")
sysConfig.sessionId = "Testing"

function sessionMessageCallback(message)
    @show message
end
function robotMessageCallback(message)
    @show message
end

kafkaService = KafkaService(sysConfig)
initialize(kafkaService, sessionMessageCallback, robotMessageCallback)

processRobotMessages(kafkaService)
sendMessage(kafkaService, sysConfig.sessionId, "Test Message")
processSessionMessages(kafkaService)
