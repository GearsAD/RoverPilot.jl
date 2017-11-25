using Base
using PyCall

include("../entities/KafkaStreamImage.jl")
include("../entities/SystemConfig.jl")

"""
A service wrapper for the Kafka-related operations. These make use of Kafka-Python
because the existing Julia Kafka library needs updating.
"""
mutable struct KafkaService
    systemConfig::SystemConfig
    kafkaModule::Nullable{PyObject}
    producer::Nullable{PyObject}
    sessConsumer::Nullable{PyObject}
    robotConsumer::Nullable{PyObject}
    sessMsgRcvCallback::Nullable{Function}
    robotMsgRcvCallback::Nullable{Function}
    processMessagesFnc::Nullable{PyObject}
    _isConnected::Bool

    KafkaService(systemConfig::SystemConfig) = new(systemConfig, nothing, nothing, nothing, nothing, nothing, nothing, nothing, false)
end

"""
Connect to the Kafka instance and create all produers and consumers.
"""
function initialize(kafkaService::KafkaService, sessionMsgRcvCallback::Function, robotMsgRcvCallback::Function)
    systemConfig = kafkaService.systemConfig
    println("Kafka: Connecting to $(systemConfig.kafkaConfig.ip):$(systemConfig.kafkaConfig.port)...");

    # E.g. https://github.com/dpkp/kafka-python/blob/master/example.py
    kafkaService.kafkaModule = pyimport("kafka")
    kafkaService.producer = get(kafkaService.kafkaModule)[:KafkaProducer]()
    kafkaService.sessMsgRcvCallback = sessionMsgRcvCallback
    kafkaService.robotMsgRcvCallback = robotMsgRcvCallback

    # Create the consumers
    # NOTE - These skip to the most recent message so we don't process the past. auto_offset_reset = 'latest'
    # Ref: https://kafka-python.readthedocs.io/en/master/apidoc/KafkaConsumer.html
    # $(systemConfig.kafkaConfig.ip):$(systemConfig.kafkaConfig.port)
    py"""
    from kafka import KafkaConsumer
    sessConsumer = KafkaConsumer(bootstrap_servers='127.0.0.1:9092', auto_offset_reset='latest', consumer_timeout_ms=1000)
    robotConsumer = KafkaConsumer(bootstrap_servers='127.0.0.1:9092', auto_offset_reset='latest', consumer_timeout_ms=1000)
    """
    kafkaService.sessConsumer = py"sessConsumer"
    println("Kafka: Connecting to topic $(systemConfig.sessionId)...")
    get(kafkaService.sessConsumer)[:subscribe]([systemConfig.sessionId])
    kafkaService.robotConsumer = py"robotConsumer"
    println("Kafka: Connecting to topic $(systemConfig.botId)...")
    get(kafkaService.robotConsumer)[:subscribe]([systemConfig.botId])

    # Define the processors
    py"""
    def processMessages(consumer, juliaCallback):
        #consumer = KafkaConsumer(bootstrap_servers='localhost:9092',
        #                             auto_offset_reset='earliest',
        #                             consumer_timeout_ms=1000)
        #consumer.subscribe(['rawImageStream'])
        for message in consumer:
            juliaCallback(message)
        #consumer.close()
    """
    kafkaService.processMessagesFnc = py"processMessages"

    kafkaService._isConnected = true
end

"""
Disconnect all consumers.
"""
function disconnect(kafkaService::KafkaService)
    if(!kafkaService._isConnected)
        return
    end

    kafkaService._isConnected = false
    get(kafkaService.sessConsumer)[:close]()
    get(kafkaService.robotConsumer)[:close]()
end

"""
Process all new session messages.
"""
function processSessionMessages(kafkaService::KafkaService)
    if(!kafkaService._isConnected)
        println("KafkaService error: Not initialized, please call connect!")
        return
    end

    get(kafkaService.processMessagesFnc)(get(kafkaService.sessConsumer), get(kafkaService.sessMsgRcvCallback))
end

"""
Process all new robot messages.
"""
function processRobotMessages(kafkaService::KafkaService)
    if(!kafkaService._isConnected)
        println("KafkaService error: Not initialized, please call connect!")
        return
    end

    get(kafkaService.processMessagesFnc)(get(kafkaService.robotConsumer), get(kafkaService.robotMsgRcvCallback))
end

"""
Send a message to a channel.
"""
function sendMessage(kafkaService::KafkaService, channel::String, data::String)
    if(!kafkaService._isConnected)
        println("KafkaService error: Not initialized, please call connect!")
        return
    end

    get(kafkaService.producer)[:send](channel, data)
end

"""
Convenience method. Send an image to the image channel.
"""
function sendRawImage(kafkaService::KafkaService, kafkaStreamImage::KafkaStreamImage)
    if(!kafkaService._isConnected)
        println("KafkaService error: Not initialized, please call connect!")
        return
    end

    sendMessage(kafkaService, kafkaService.systemConfig.kafkaConfig.rawImageChannelName, encode(kafkaStreamImage))
end
