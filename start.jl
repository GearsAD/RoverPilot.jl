### Some playtime with the little guys Rover2.
### REF: http://blog.leahhanson.us/post/julia/julia-calling-python.html

# Installs
# Pkg.add("Images")
# Pkg.add("ImageView")
# Pkg.add("PyCall")
# Pkg.add("CloudGraphs")
# Pkg.add("ProgressMeter")
# Pkg.add("JSON")
# Pkg.add("Unmarshal")

using Base
using PyCall
using FileIO
using CloudGraphs
using Caesar, IncrementalInference, RoME
using KernelDensityEstimate
using SlamInDB_APICommon
using ArgParse
# include("ExtensionMethods.jl")

@everywhere include("./entities/RoverPose.jl")

# Allow the local directory to be used
cd("/home/gears/roverlock");
unshift!(PyVector(pyimport("sys")["path"]), "")

# Globals
shouldRun = true
# Let's use some local FIFO's here.
@everywhere sendPoseQueue = Channel{RoverPose}(100)

"""
Send data to database.
"""
function nodeTransmissionLoop(sysConfig::SystemConfig, fg::IncrementalInference.FactorGraph, kafkaService::KafkaService)
    # Get from sysConfig
    Podo=diagm([0.1;0.1;0.005]) # TODO ASK: Noise?
    N=100

    println("[SendNodes Loop] Started!")
    while shouldRun
        try
            pose = take!(sendPoseQueue)
            println("[SendNodes Loop] SendQueue got message, sending $(poseIndex(pose))!")

            @time lastPoseVertex, factorPose = addOdoFG!(fg, poseIndex(pose), odoDiff(pose), Podo, N=N, labels=["POSE", pose.poseId, sysConfig.botId])
            # Now send the images.
            for robotImg = pose.camImages
                ksi = ImageData(string(Base.Random.uuid4()), pose.poseId, sysConfig.sessionId, String(poseIndex(pose)), robotImg.timestamp, robotImg.camJpeg, "jpg", Dict{String, String}())
                @time sendRawImage(kafkaService, ksi)
            end
        catch e
            println("[SendNodes Loop] Error seding node!")
            bt = catch_backtrace()
            showerror(STDOUT, e, bt)
        end
        println("[SendNodes Loop] Sent message!")
    end
    println("[SendNodes Loop] Done!")
end

function juliaDataLoop(sysConfig::SystemConfig, rover)
    # Make the initial pose, assuming start pose is 0,0,0 - setting the time to now.
    curPose = RoverPose()
    curPose.timestamp = Base.Dates.datetime2unix(now())
    # Bump it to x2 because we already have x1 (curPose = proposed pose, not saved yet)
    curPose.poseIndex = 2

    lastSend = Nullable{Task}

    println("[Julia Data Loop] Should run = $shouldRun");
    while shouldRun
        # Update the data acquisition
        rover[:iterateDataProcessor]()
        # Check length of queue
        # println("[Julia Data Loop] Image frame count = $frameCount");
        while rover[:getRoverStateCount]() > 0
            roverState = rover[:getRoverState]()
            append!(curPose, roverState, sysConfig.botConfig.maxImagesPerPose)
#            println(curPose)
            if (isPoseWorthy(curPose))
                println("Promoting Pose $(poseIndex(curPose)) to CloudGraphs!")
                put!(sendPoseQueue, curPose)
                curPose = RoverPose(curPose) # Increment pose
            end
            sleep(0.01)
        end
    end
    print("[Julia Data Loop] I'm out!");
end

"""
Get the command-line parameters.
"""
function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "sysConfig"
            help = "Provide a system configuration file"
            default = "./config/systemconfig_aws.json"
    end

    return parse_args(s)
end

function main()
    # Parse command lines.
    parsedArgs = parse_commandline()

    println(" --- Loading system config from '$(parsedArgs["sysConfig"])'...")
    sysConfig = readSystemConfigFile(parsedArgs["sysConfig"])
    sysConfig.sessionId = sysConfig.botId * "_" * (!isempty(strip(sysConfig.sessionPrefix)) ? sysConfig.sessionPrefix * "_" : "") * string(Base.Random.uuid1())[1:8] #Name+SHA

    # Connect to CloudGraphs
    println(" --- Connecting to CloudGraphs instance $(sysConfig.cloudGraphsConfig.neo4jHost)...")
    cloudGraph = connect(sysConfig.cloudGraphsConfig);
    conn = cloudGraph.neo4j.connection;
    # register types of interest in CloudGraphs
    registerGeneralVariableTypes!(cloudGraph)
    Caesar.usecloudgraphsdatalayer!()
    println("Current session: $(sysConfig.sessionId)")

    # Kafka Initialization - callbacks not used yet.
    # Kafka Initialization
    println(" --- Connecting to Kafka instance $(sysConfig.kafkaConfig.ip)...")
    function sessionMessageCallback(message)
        @show typeof(message)
    end
    function robotMessageCallback(message)
        @show message
    end
    kafkaService = KafkaService(sysConfig)
    initialize(kafkaService, Vector{KafkaConsumer}())
    # Send a status message to say we're up!
    sendStatusNotification(kafkaService, StatusNotification(sysConfig.botId, sysConfig.sessionId, "ACTIVE"))

    # Now start up our factor graph.
    fg = Caesar.initfg(sessionname=sysConfig.sessionId, cloudgraph=cloudGraph)
    # Initialize the factor graph and insert first pose.
    lastPoseVertex = initFactorGraph!(fg, labels=[sysConfig.botId])

    println(" --- Starting out transmission loop!")
    sendLoop = @async nodeTransmissionLoop(sysConfig, fg, kafkaService)

    # Let's do some importing
    # Ref: https://github.com/JuliaPy/PyCall.jl/issues/53
    println(" --- Connecting to Rover!")
    roverModule = pyimport("RoverPylot")
    rover = roverModule[:PS3Rover](sysConfig.botConfig.deadZoneNorm, sysConfig.botConfig.maxRotSpeed, sysConfig.botConfig.maxTransSpeed)
    # Initialize
    rover[:initialize]()

    println(" --- Current session: $(sysConfig.sessionId)")

    # Start the main loop
    println(" --- Success, starting main processing loop!")
    dataLoop = juliaDataLoop(sysConfig, rover)

    wait(dataLoop)
    wait(sendLoop)
end

main()
