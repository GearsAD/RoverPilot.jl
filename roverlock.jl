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
using Caesar, IncrementalInference, RoME
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

# function pushCloudGraphsPose(curPose::RoverPose)
#     return false
# end

function juliaDataLoop(rover, fg::IncrementalInference.FactorGraph)
    # Tuning params - Move these out.
    Podo=diagm([0.1;0.1;0.005]) # TODO ASK: Noise?
    N=100
    lcmode=:unimodal # TODO ASK: Solver?
    lsrNoise=diagm([0.1;1.0]) # TODO ASK: ?

    # Initialize the factor graph and insert first pose.
    lastPoseVertex = initFactorGraph!(fg)

    # Make the initial pose, assuming start pose is 0,0,0 - setting the time to now.
    curPose = RoverPose()
    curPose.timestamp = Base.Dates.datetime2unix(now())
    # Bump it to x2 because we already have x1 (curPose = proposed pose, not saved yet)
    curPose.poseIndex = 2

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
                @time lastPoseVertex, factorPose = addOdoFG!(fg, poseIndex(curPose), odoDiff(curPose), Podo, N=N, labels=["POSE"])
                curPose = RoverPose(curPose) # Increment pose
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
println("Current session: $session")

fg = Caesar.initfg(sessionname=session, cloudgraph=cloudGraph)


# robot style, add first pose vertex
# REF: https://github.com/dehann/Caesar.jl/blob/master/examples/wheeled/victoriapark_onserver.jl
# lastPoseVertex = initFactorGraph!(fg)
# curPose = RoverPose();
# curPose.timestamp = Base.Dates.datetime2unix(now())
# # Bump to x2 so we don't have two x1's (x1 = base node)
# curPose.poseIndex = 2
# curPose.x += 1
# curPose.y += 1
# @time lastPoseVertex, factorPose = addOdoFG!(fg, poseIndex(curPose), odoDiff(curPose), Podo, N=N, labels=["POSE"])
# curPose = RoverPose(curPose)

# Let's do some importing
# Ref: https://github.com/JuliaPy/PyCall.jl/issues/53
roverModule = pyimport("RoverPylot")
rover = roverModule[:PS3Rover](deadZoneNorm, maxRotSpeed, maxTransSpeed)

# Initialize
rover[:initialize]()
# Start the main loop
juliaDataLoop(rover, fg)
