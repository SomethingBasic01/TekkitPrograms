-- Locate the tape drive peripheral
local tape = peripheral.find("tape_drive")
if not tape then
    print("This program requires a tape drive to run.")
    return
end

-- Set the playback speed (adjust if necessary)
local speed = 1
tape.setSpeed(speed)

-- Function to check if the tape is currently playing
local function isTapePlaying()
    return tape.getState() == "PLAYING"
end

-- Function to rewind the tape
local function rewindTape()
    tape.stop()
    tape.seek(-tape.getSize()) -- Rewind to the start of the tape
    print("Tape rewound.")
end

-- Function to play the tape
local function playTape()
    if not isTapePlaying() then
        tape.play()
        print("Tape is playing.")
    end
end

-- Function to stop the tape
local function stopTape()
    if isTapePlaying() then
        tape.stop()
        print("Tape stopped.")
    end
end

-- Function to monitor the tape and rewind if silence or end is detected
local function monitorTape()
    if tape.read() == 0 or tape.isEnd() then
        print("No sound detected or end of tape reached, rewinding...")
        rewindTape()
        playTape() -- Start playing the tape again
    end
end

-- Monitor redstone input to control tape playback
while true do
    if redstone.getInput("back") then  -- Adjust the side as needed
        -- If redstone signal is detected, play the tape on loop
        playTape()
        while redstone.getInput("back") do
            monitorTape()  -- Continuously monitor for silence or end of tape
            sleep(1) -- Check every second while playing
        end
    else
        -- If redstone signal is off, stop and rewind the tape
        stopTape()
        rewindTape()
    end
    sleep(0.5) -- Check redstone input every half second
end
