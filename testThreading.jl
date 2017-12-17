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
using FileIO

# include("ExtensionMethods.jl")

# Globals
shouldRun = true
# Let's use some local FIFO's here.
@everywhere sendPoseQueue = Channel{String}(100)

"""
Send data to database.
"""
function sendThread()
    println("[SendNodes Loop] Started!")
    while shouldRun
        try
            pose = take!(sendPoseQueue)
            println("[SendNodes Loop] SendQueue got message $(pose)!")
        catch e
            println("[SendNodes Loop] Error seding node!")
            bt = catch_backtrace()
            showerror(STDOUT, e, bt)
        end
        println("[SendNodes Loop] Sent message!")
    end
    println("[SendNodes Loop] Done!")
end

function juliaDataLoop()
    println("[Julia Data Loop] Should run = $shouldRun");
    while shouldRun
        sleep(1)
        put!(sendPoseQueue, "1234")
        println("[Julia Data Loop] Added message!")
    end
    print("[Julia Data Loop] I'm out!");
end


function main()
    println(" --- Starting out transmission loop!")
    sendLoop = @spawn sendThread()

    println(" --- Success, starting main processing loop!")
    dataLoop = juliaDataLoop()

    wait(dataLoop)
    wait(sendLoop)
end

main()
