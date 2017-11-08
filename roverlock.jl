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

# Allow the local directory to be used
cd("/home/gears/roverlock");
unshift!(PyVector(pyimport("sys")["path"]), "")

shouldRun = true

function juliaDataLoop(rover)
    println("[Julia Data Loop] Should run = $shouldRun");
    while shouldRun
        # Check length of queue
        rover[:iterateDataProcessor]()
        frameCount = rover[:getBotFrameCount]()
        println("[Julia Data Loop] Image frame count = $frameCount");
        imIndex = 1
        while frameCount > 0
            frame = rover[:getFrame]()
            # Temporary writeout
            out = open("image$imIndex.jpg","w")
            write(out,frame)
            close(out)
            # imIndex = imIndex+1
            # println("[Julia Data Loop] Got image = $frame");
            frameCount = rover[:getBotFrameCount]()
        end
        # sleep(1);
    end
    print("[Julia Data Loop] I'm out!");
end

# Let's do some importing
# Ref: https://github.com/JuliaPy/PyCall.jl/issues/53
roverModule = pyimport("RoverPylot")
rover = roverModule[:PS3Rover]()

# Initialize
rover[:initialize]()
# Start it.
# pythonLoop = @async rover[:robotLoop]()
juliaDataLoop(rover)
# wait(juliaLoop)
