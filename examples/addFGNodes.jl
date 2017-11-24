using CloudGraphs
using Caesar, IncrementalInference, RoME
using KernelDensityEstimate

include("../entities/roverPose.jl")

configuration = CloudGraphs.CloudGraphConfiguration("localhost", 7474, "neo4j", "neo5j", "localhost", 27017, false, "", "");
cloudGraph = connect(configuration);
conn = cloudGraph.neo4j.connection;
session = "RoverLock_" * string(Base.Random.uuid1())[1:8] #Name+SHA
# register types of interest in CloudGraphs
registerGeneralVariableTypes!(cloudGraph)
Caesar.usecloudgraphsdatalayer!()
println("Current session: $session")

fg = Caesar.initfg(sessionname=session, cloudgraph=cloudGraph)

# REF: https://github.com/dehann/Caesar.jl/blob/master/examples/wheeled/victoriapark_onserver.jl
# Tuning params - Move these out.
Podo=diagm([0.1;0.1;0.005]) # TODO ASK: Noise?
N=100
lcmode=:unimodal # TODO ASK: Solver?
lsrNoise=diagm([0.1;1.0]) # TODO ASK: ?

lastPoseVertex = initFactorGraph!(fg)
curPose = RoverPose();
curPose.timestamp = Base.Dates.datetime2unix(now())
# Bump to x2 so we don't have two x1's (x1 = base node)
curPose.poseIndex = 2
for i = 1:2
    curPose.x += 1
    curPose.y += 1
    @time lastPoseVertex, factorPose = addOdoFG!(fg, poseIndex(curPose), odoDiff(curPose), Podo, N=N, labels=["POSE"])
    curPose = RoverPose(curPose)
end
