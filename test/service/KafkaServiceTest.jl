using Base
using Base.Test

include("../../service/KafkaService.jl")

sysConfig = readSystemConfigFile(dirname(Base.source_path()) *"/../../config/systemconfig.json")
sysConfig.sessionId = "Testing"

function sessionMessageCallback(message)
    @show typeof(message)
end
function robotMessageCallback(message)
    @show message
end

kafkaService = KafkaService(sysConfig)
initialize(kafkaService, sessionMessageCallback, robotMessageCallback)

# Test the bot messae system
@time sendMessage(kafkaService, sysConfig.botId, "Test Bot Message")
@time processRobotMessages(kafkaService)

# Load a representative messages
# Load a test binary file
fid = open(dirname(Base.source_path()) * "/test.jpg","r")
imgBytes = read(fid)
close(fid)

# Basic testing to validate that the structure can be encoded
ksiTest = KafkaStreamImage("x1", sysConfig.sessionId, 0, imgBytes, Dict{String, String}("Test" => "TestAgain"))
println("Time for sending 100 Kafka images:")
@time for i = 1:100
    sendMessage(kafkaService, sysConfig.sessionId, encode(ksiTest))
end
println("Time for receiving 100 Kafka images:")
@time processSessionMessages(kafkaService)
