using PyCall

export saveImage, append
export RoverPose

struct RoverImage
    timestamp::Float64
    camJpeg::AbstractString
end

mutable struct RoverPose
    timestamp::Float64
    x::Float64
    y::Float64
    theta::Float64
    camImages::Vector{RoverImage}
    prevPose::Nullable{RoverPose}
    # Other stuff like AprilTags here

    # RoverPose(timestamp::Float64, locX::Float64, locY::Float64, theta::Float64, camJpeg::AbstractString) = new(timestamp, locX, locY, theta, camJpeg)
    RoverPose(prevPose::RoverPose) = new(prevPose.timestamp, prevPose.x, prevPose.y, prevPose.theta, Vector{RoverImage}(), prevPose)
    RoverPose() = new(0, 0, 0, 0, Vector{RoverImage}(0), nothing)
end

Base.show(io::IO, roverPose::RoverPose) = @printf "[%0.3f] At (%0.2f, %0.2f) with heading %0.2f and %d images" roverPose.timestamp roverPose.x roverPose.y roverPose.theta length(roverPose.camImages)

function saveImage(roverImage :: RoverImage, imFile :: AbstractString)
    out = open(imFile,"w")
    write(out,roverImage.camJpeg)
    close(out)
end

function append!(roverPose::RoverPose, newRoverState::PyCall.PyObject, maxImages = 100)
    duration = newRoverState[:getDuration]()
    endTime = newRoverState[:getEndTime]()
    jpegBytes = newRoverState[:getImage]()
    push!(roverPose.camImages, RoverImage(endTime, jpegBytes))
    while(length(roverPose.camImages) > maxImages)
        pop!(roverPose.camImages)
    end
    # Timestamp
    roverPose.timestamp = endTime
    # Should be either rotation or translation but not both at same time
    roverPose.theta += duration * newRoverState[:getRotSpeedNorm]()
    roverPose.x -= duration * sin(roverPose.theta) * newRoverState[:getTransSpeedNorm]()
    roverPose.y += duration * cos(roverPose.theta) * newRoverState[:getTransSpeedNorm]()
    #println("Duration = $(duration), updated position = $(roverPose.x), $(roverPose.y)")
end

function isPoseWorthy(roverPose::RoverPose)
    return true
end
