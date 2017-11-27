import JSON

export KafkaStreamImage
export encode, decode

mutable struct KafkaStreamImage
    poseIndex::String
    sessionId::String
    timestamp::Float64
    imageBytes::Vector{UInt8} #Byte array
    imageFormat::String
    additionalInfo::Dict{String, String}

    KafkaStreamImage(poseIndex, sessionId, timestamp, imageBytes, imageFormat, additionalInfo = Dict{String, String}()) = new(poseIndex, sessionId, timestamp, imageBytes, imageFormat, additionalInfo);
    KafkaStreamImage() = new("", "", Base.Dates.datetime2unix(now()), Vector{UInt8}(), "", Dict{String, String}());
end

# Using JSON for now, we look at more optimal once we get MVP working and/or this becomes a performance issue

function encode(ksi::KafkaStreamImage)::String
    return JSON.json(ksi)
end

function decode(data::String)::KafkaStreamImage
    interm = JSON.parse(data)
    return KafkaStreamImage(interm["poseIndex"], interm["sessionId"], interm["timestamp"], interm["imageBytes"], interm["imageFormat"], interm["additionalInfo"])
end

println("Thanks for importing KafkaStreamImage :)")
