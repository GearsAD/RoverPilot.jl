
export saveImage
export RoverPose

struct RoverPose
  timestamp::Float64
  x::Float64
  y::Float64
  theta::Float64
  camJpeg::AbstractString
  # Other stuff like AprilTags here

  RoverPose(timestamp::Float64, locX::Float64, locY::Float64, theta::Float64, camJpeg::AbstractString) = new(timestamp, locX, locY, theta, camJpeg)
  RoverPose(fromPose::RoverPose, distance::Float64, theta::Float64, camJpeg::AbstractString) = new(fromPose.x - distance * sin(theta), fromPose.y + distance * cos(theta), theta, camJpeg)
  RoverPose() = new(0, 0, 0, 0, [])
end

Base.show(io::IO, roverPose::RoverPose) = print(io, "[$(roverPose.x), $(roverPose.y)] with heading $(roverPose.theta))")

function saveImage(roverPose :: RoverPose, imFile :: AbstractString)
    out = open(imFile,"w")
    write(out,roverPose.camJpeg)
    close(out)
end
