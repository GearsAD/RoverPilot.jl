### Some playtime with the little guys Rover2.
### REF: http://blog.leahhanson.us/post/julia/julia-calling-python.html

# Installs
# Pkg.add("Images")
# Pkg.add("ImageView")
# Pkg.add("PyCall")
# Pkg.add("CloudGraphs")

using PyCall
using FileIO
# using CloudGraphs

include("roverPose.jl")

# Allow the local directory to be used
cd("/home/gears/roverlock");
unshift!(PyVector(pyimport("sys")["path"]), "")

shouldRun = true
curPose = [0, 0, 0] # X, Y, Theta
movementCoefficients = [] #ms^-1 and rads^-1

# function pushCloudGraphsFrame(image, wheelOdo)

function juliaDataLoop(rover)
    println("[Julia Data Loop] Should run = $shouldRun");
    while shouldRun
        # Update the data acquisition
        rover[:iterateDataProcessor]()
        # Check length of queue
        # println("[Julia Data Loop] Image frame count = $frameCount");
        while rover[:getRoverStateCount]() > 0
            pose = rover[:getRoverState]()
        end
    end
    print("[Julia Data Loop] I'm out!");
end

# Let's do some importing
# Ref: https://github.com/JuliaPy/PyCall.jl/issues/53
roverModule = pyimport("RoverPylot")
rover = roverModule[:PS3Rover]()

# Initialize
rover[:initialize]()
# Start the main loop
juliaDataLoop(rover)
