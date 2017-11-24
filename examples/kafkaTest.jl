# https://hevodata.com/blog/how-to-set-up-kafka-on-ubuntu-16-04/
# Using Python
# pip install kafka-python
using PyCall
using FileIO

function messageCallback(message)
    @show message
end

py"""
from kafka import KafkaConsumer
consumer = KafkaConsumer(bootstrap_servers='localhost:9092', auto_offset_reset='earliest', consumer_timeout_ms=1000)
"""
consumer = py"consumer"
consumer[:subscribe](["rawImageStream"])

py"""
from kafka import KafkaConsumer
def processMessages(consumer, juliaCallback):
    #consumer = KafkaConsumer(bootstrap_servers='localhost:9092',
    #                             auto_offset_reset='earliest',
    #                             consumer_timeout_ms=1000)
    consumer.subscribe(['rawImageStream'])
    for message in consumer:
        print(message)
        juliaCallback(message)
    #consumer.close()
"""
processMessages = py"processMessages"
processMessages(consumer, messageCallback)
consumer[:close]()
