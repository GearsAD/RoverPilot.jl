using Base
using Base.Test

include("../../entities/KafkaStreamImage.jl")

# Load a test binary file
fid = open(dirname(Base.source_path()) *"/test.jpg","r")
imgBytes = read(fid)
close(fid)

# Basic testing to validate that the structure can be encoded
ksiTest = KafkaStreamImage("x1", "TESTSESS", 0, imgBytes, "jpg", Dict{String, String}("Test" => "TestAgain"))
byteData = encode(ksiTest)
ksiCompare = decode(byteData)
@test ksiTest.poseIndex == ksiCompare.poseIndex
@test ksiTest.sessionId == ksiCompare.sessionId
@test ksiTest.imageBytes == ksiCompare.imageBytes
@test ksiTest.imageFormat == ksiCompare.imageFormat
@test ksiTest.additionalInfo == ksiCompare.additionalInfo
