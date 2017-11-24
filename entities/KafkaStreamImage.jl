import JSON

export KafkaStreamImage
export encode, decode

mutable struct KafkaStreamImage
    poseIndex::String
    sessionId::String
    timestamp::Float64
    camJpeg::Vector{UInt8} #Byte array
    additionalInfo::Dict{String, String}

    KafkaStreamImage(poseIndex, sessionId, timestamp, camJpeg, additionalInfo) = new(poseIndex, sessionId, timestamp, camJpeg, additionalInfo);
    KafkaStreamImage() = new("", "", 0, Vector{UInt8}(), Dict{String, String}());
end

# Using JSON for now, we look at more optimal once we get MVP working and/or this becomes a performance issue

function encode(ksi::KafkaStreamImage)::String
    return JSON.json(ksi)
end

function decode(data::String)::KafkaStreamImage
    interm = JSON.parse(data)
    return KafkaStreamImage(interm["poseIndex"], interm["sessionId"], interm["timestamp"], interm["camJpeg"], interm["additionalInfo"])
end

println("Thanks for importing KafkaStreamImage :)")
