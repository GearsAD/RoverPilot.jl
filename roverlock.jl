### Some playtime with the little guys Rover2.
### REF: http://blog.leahhanson.us/post/julia/julia-calling-python.html

# Installs
# Pkg.add("Images")
# Pkg.add("ImageView")
# Pkg.add("PyCall")
# Pkg.add("CloudGraphs")
# Pkg.add("ProgressMeter")

using PyCall
using FileIO
using CloudGraphs
using Caesar, IncrementalInference
using KernelDensityEstimate
# include("ExtensionMethods.jl")

include("roverPose.jl")

# Allow the local directory to be used
cd("/home/gears/roverlock");
unshift!(PyVector(pyimport("sys")["path"]), "")

shouldRun = true
# Coefficients
deadZoneNorm = 0.05
maxRotSpeed = 0.5
maxTransSpeed = 0.3
rotNormToRadCoeff = 1 #TODO - calculate
transNormToMetersCoeff = 1 #TODO - calculate
maxImagesPerPose = 100

function pushCloudGraphsPose(curPose::RoverPose)
    return false
end

function juliaDataLoop(rover)
    # Make the initial pose, assuming start pose is 0,0,0 - setting the time to now.
    curPose = RoverPose()
    curPose.timestamp = Base.Dates.datetime2unix(now())
    pushCloudGraphsPose(curPose)

    println("[Julia Data Loop] Should run = $shouldRun");
    while shouldRun
        # Update the data acquisition
        rover[:iterateDataProcessor]()
        # Check length of queue
        # println("[Julia Data Loop] Image frame count = $frameCount");
        while rover[:getRoverStateCount]() > 0
            roverState = rover[:getRoverState]()
            append!(curPose, roverState, maxImagesPerPose)
            println(curPose)
            if (isPoseWorthy(curPose))
                print("Promoting Pose to CloudGraphs!")
                pushCloudGraphsPose(deepcopy(curPose))
                curPose = RoverPose(curPose)
            end
        end
    end
    print("[Julia Data Loop] I'm out!");
end

# Connect to CloudGraphs
configuration = CloudGraphs.CloudGraphConfiguration("localhost", 7474, "neo4j", "neo5j", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);
conn = cloudGraph.neo4j.connection;
session = "RoverLock_" * string(Base.Random.uuid1())[1:8]
# register types of interest in CloudGraphs
registerGeneralVariableTypes!(cloudGraph)
Caesar.usecloudgraphsdatalayer!()

# Let's do some importing
# Ref: https://github.com/JuliaPy/PyCall.jl/issues/53
roverModule = pyimport("RoverPylot")
rover = roverModule[:PS3Rover](deadZoneNorm, maxRotSpeed, maxTransSpeed)

# Initialize
rover[:initialize]()
# Start the main loop
juliaDataLoop(rover)
