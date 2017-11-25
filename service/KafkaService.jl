using PyCall

import("../entities/KafkaStreamImage.jl")
import("../entities/SystemConfig.jl")

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

function connect(kafkaService::KafkaService, sessionMsgRcvCallback::Function, robotMsgRcvCallback::Function)
    println("Kafka: Connecting to $(kafkaConfig.ip):$(kafkaConfig.port)...");

    # E.g. https://github.com/dpkp/kafka-python/blob/master/example.py
    kafkaService.kafkaModule = pyimport("kafka")
    kafkaService.producer = kafkaModule[:KafkaProducer]()
    kafkaService.sessMsgRcvCallback = sessionMsgRcvCallback
    kafkaService.robotMsgRcvCallback = robotMsgRcvCallback

    # Create the consumers
    # NOTE - These skip to the most recent message so we don't process the past. auto_offset_reset = 'latest'
    # Ref: https://kafka-python.readthedocs.io/en/master/apidoc/KafkaConsumer.html
    py"""
    from kafka import KafkaConsumer
    sessConsumer = KafkaConsumer(bootstrap_servers='$(systemConfig.kafkaConfig.ip):$(systemConfig.kafkaConfig.port)', auto_offset_reset='latest', consumer_timeout_ms=1000)
    robotConsumer = KafkaConsumer(bootstrap_servers='$(systemConfig.kafkaConfig.ip):$(systemConfig.kafkaConfig.port)', auto_offset_reset='latest', consumer_timeout_ms=1000)
    """
    kafkaService.sessConsumer = py"sessConsumer"
    kafkaService.sessConsumer[:subscribe]([systemConfig.sessionId])
    kafkaService.robotConsumer = py"robotConsumer"
    kafkaService.robotConsumer[:subscribe]([systemConfig.botId])

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

function disconnect(kafkaService::KafkaService)
    kafkaService.sessConsumer[:close]()
    kafkaService.robotConsumer[:close]()

function processSessionMessages(kafkaService::KafkaService)
    kafkaService.processMessagesFnc(kafkaService.sessConsumer, kafkaService.sessMsgRcvCallback)

function processRobotMessages(kafkaService::KafkaService)
    kafkaService.processMessagesFnc(kafkaService.robotConsumer, kafkaService.robotMsgRcvCallback)

function sendImage(kafkaService::KafkaService, kafkaStreamImage::KafkaStreamImage)
    kafkaService.producer[:send](kafkaService.systemConfig.kafkaConfig.rawImageChannelName, encode(kafkaStreamImage))
