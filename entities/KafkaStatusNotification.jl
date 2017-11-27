import JSON

export KafkaStatusNotification
export encode, decode

mutable struct KafkaStatusNotification
    robotId::String
    sessionId::String
    timestamp::Float64
    status::String
    additionalInfo::Dict{String, String}

    KafkaStatusNotification(robotId, sessionId, status, timestamp=Base.Dates.datetime2unix(now()), additionalInfo=Dict{String, String}()) = new(robotId, sessionId, timestamp, status, additionalInfo);
    KafkaStatusNotification() = new("", "", Base.Dates.datetime2unix(now()), "", Dict{String, String}());
end

# Using JSON for now, we look at more optimal once we get MVP working and/or this becomes a performance issue

function encode(ksi::KafkaStatusNotification)::String
    return JSON.json(ksi)
end

function decode(data::String)::KafkaStatusNotification
    interm = JSON.parse(data)
    return KafkaStreamImage(interm["robotId"], interm["sessionId"], interm["timestamp"], interm["status"], interm["additionalInfo"])
end

println("Thanks for importing KafkaStatusNotification :)")
