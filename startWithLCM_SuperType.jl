### Some playtime with the little Rover2.
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
using SynchronySDK
using ArgParse

using LCMCore, CaesarLCMTypes

@everywhere include("./entities/RoverPose.jl")
@everywhere include("./entities/SystemConfig.jl")

# Allow the local directory to be used
cd(Pkg.dir("RoverPilot"))
unshift!(PyVector(pyimport("sys")["path"]), "")

# Globals
shouldRun = true
# Let's use some local FIFO's here.
@everywhere sendPoseQueue = Channel{RoverPose}(100)

### SYNCHRONY CONFIG
using Base
using JSON, Unmarshal
using SynchronySDK
using SynchronySDK.DataHelpers

function publishLCMOdoVariableFactorImage(lcm::LCM,
            utime::Int64,
            prevId::Union{Void, String},
            newId::String,
            deltaMeasurement::Vector{<:Real},
            pOdo,
            camBytes::Vector{UInt8})
  #
  superType = brookstone_supertype_t()

  varmsg = generic_variable_t()
  varmsg.utime = utime
  varmsg.variablelabel = string(newId)
  varmsg.variabletype = "Pose2"
  # varmsg.datadescription
  # varmsg.datalength::Int32
  # varmsg.data =

  superType.newvariable = varmsg

  fctdict = Dict{String, Any}()
  fctdict["podo"] = pOdo[:]
  fctdict["meas"] = deltaMeasurement[:]
  fctdict["prob_model"] = "MvNormal"

  previdval = prevId != nothing ? prevId : ""
  fctmsg = generic_factor_t()
  fctmsg.utime = utime#::Int64
  fctmsg.variablelabels = String[previdval; newId]
  fctmsg.numvariables = length(fctmsg.variablelabels)
  fctmsg.factortype = "Pose2Pose2"
  fctmsg.datadescription = "Dict{String, Any}()"
  fctmsg.data = take!(IOBuffer(json(fctdict)))
  fctmsg.datalength = length(fctmsg.data)

  superType.newfactor = fctmsg

  camImage = image_t()
  camImage.utime = utime
  camImage.width = 640
  camImage.height = 480
  camImage.row_stride = 3
  camImage.pixelformat = 1196444237
  camImage.size = length(camBytes)
  camImage.data = camBytes
  camImage.nmetadata = 0
  camImage.metadata = Vector{image_metadata_t}()

  superType.img = camImage

  publish(lcm, "BROOKSTONE_ROVER", LCMCore.encode(superType))

  nothing
end

"""
Send odometry and camera data to database at each keyframe/pose instantiation event via SynchronySDK.
"""
function nodeTransmissionLoop(sysConfig::SystemConfig)
    # Get from sysConfig
    # Podo=diagm([0.1;0.1;0.005]) # TODO ASK: Noise?
    N=100
    # Make a new LCM
    LCM() do lcm
        println("[SendNodes Loop] Started!")
        while shouldRun
            # try
            @show pose = take!(sendPoseQueue)
            println("[SendNodes Loop] SendQueue got message, sending $(poseIndex(pose))!")

            @show deltaMeasurement = odoDiff(pose) #[10.0;0;pi/3]
            utime = Int64(floor(time()*1000*1000))
            pOdo = diagm([0.1;0.1;0.005])
            println(" - Measurement: Adding new odometry measurement '$deltaMeasurement'...")
            # newOdometryMeasurement = AddOdometryRequest(deltaMeasurement, pOdo)
            # addOdoResponse = addOdometryMeasurement(synchronyConfig, robotId, sessionId, newOdometryMeasurement)

            # publish LCM node and factor messages
            prevIndex = isnull(pose.prevPose) ? "" : "x$(get(pose.prevPose).poseIndex)"

            println(" - Adding image data to node with timestamp $utime")
            for robotImg = pose.camImages
                publishLCMOdoVariableFactorImage(lcm, utime, prevIndex, "x$(pose.poseIndex)", deltaMeasurement, pOdo, take!(IOBuffer(robotImg.camJpeg)))
                # REF: https://github.com/RobotLocomotion/libbot/blob/master/bot2-core/lcmtypes/bot_core_image_t.lcm#L26-L62
            end
            println("[SendNodes Loop] Sent message!")
            # sleep(1)
        end
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
            sleep(0.005)
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

    # println(" --- Starting out transmission loop!")
    sendLoop = @async nodeTransmissionLoop(sysConfig)
    println(" --- Sleeping!")
    sleep(10)

    # Let's do some importing
    # Ref: https://github.com/JuliaPy/PyCall.jl/issues/53
    println(" --- Connecting to Rover!")
    roverModule = pyimport("RoverPylot")
    rover = roverModule[:PS3Rover](sysConfig.botConfig.deadZoneNorm, sysConfig.botConfig.maxRotSpeed, sysConfig.botConfig.maxTransSpeed)
    # Initialize
    rover[:initialize]()

    # println(" --- Current session: $(sessionId)")

    # Start the main loop
    println(" --- Success, starting main processing loop!")
    dataLoop = juliaDataLoop(sysConfig, rover)

    wait(dataLoop)
    wait(sendLoop)
end

main()
