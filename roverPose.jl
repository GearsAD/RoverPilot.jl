struct RoverPose
  x::Float64
  y::Float64
  theta::Float64
  camJpeg::AbstractString
  # Other stuff like AprilTags here

  RoverPose(locX::Float64, locY::Float64, theta::Float64, camJpeg::AbstractString) = new(locX, locY, theta, camJpeg)
  RoverPose(fromPose::RoverPose, distance::Float64, theta::Float64, camJpeg::AbstractString) = new(fromPose.x - distance * sin(theta), fromPose.y + distance * cos(theta), theta, camJpeg)
  RoverPose() = new(0, 0, 0, [])
end

Base.show(io::IO, roverPose::RoverPose) = print(io, "[$(roverPose.x), $(roverPose.y)] with heading $(roverPose.theta))")

saveImage(roverPose <: RoverPose, imFile <: AbstractString)
    out = open("image$imIndex.jpg","w")
    write(out,frame)
    close(out)
end
