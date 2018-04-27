#!/usr/bin/env python

'''
ps3rover20.py Drive the Brookstone Rover 2.0 via the P3 Controller, displaying
the streaming video using OpenCV.

Copyright (C) 2014 Simon D. Levy

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
'''

# You may want to adjust these buttons for your own controller
BUTTON_LIGHTS      = 3  # Square button toggles lights
BUTTON_STEALTH     = 1  # Circle button toggles stealth mode
BUTTON_CAMERA_UP   = 0  # Triangle button raises camera
BUTTON_CAMERA_DOWN = 2  # X button lowers camera

# Avoid button bounce by enforcing lag between button events
MIN_BUTTON_LAG_SEC = 0.5

# Avoid close-to-zero values on axis
MIN_AXIS_ABSVAL    = 1.0


from rover import Rover20


import time
import pygame
import sys
import signal
import time

# Supports CTRL-C to override threads
def _signal_handler(signal, frame):
    frame.f_locals['rover'].close()
    sys.exit(0)

# Try to start OpenCV for video
try:
    import cv
except:
    cv = None

"""
Rover state class with some meta for calculating information about the edges between states
"""
class RoverState():
    def __init__(self):
        self.jpegBytes = ""
        self.startTime = time.time()
        self.rotSpeedNorm = 0
        self.transSpeedNorm = 0
        self.endTime = self.startTime

    def setRotAndTrans(self, rotSpeedNorm, transSpeedNorm):
        self.rotSpeedNorm = rotSpeedNorm
        self.transSpeedNorm = transSpeedNorm

    def getImage(self):
        return self.jpegBytes

    def setImage(self, jpegBytes):
        self.jpegBytes = jpegBytes

    def getStartTime(self):
        return self.startTime

    def getRotSpeedNorm(self):
        return self.rotSpeedNorm

    def getTransSpeedNorm(self):
        return self.transSpeedNorm

    def getEndTime(self):
        return self.endTime

    def setEndTime(self, endTime):
        self.endTime = endTime

    def getDuration(self):
        return self.endTime - self.startTime


# Rover subclass for PS3 + OpenCV
class PS3Rover(Rover20):

    def __init__(self, deadZoneNorm, maxRotSpeed, maxTransSpeed):
        print "[Python] Rover Module constructor called..."
        print "[Python] Using coefficients: "
        print "[Python]  --- Joystick dead zone: " + str(deadZoneNorm)
        print "[Python]  --- Max rotation speed (norm): " + str(maxRotSpeed)
        print "[Python]  --- Max translation speed (norm): " + str(maxTransSpeed)
        # print " --- Coefficients of rotation and translation: " + str(rotToRadCoeff) + ", " + str(transToTransCoeff)

        self.deadZoneNorm = deadZoneNorm
        self.maxRotSpeed = maxRotSpeed
        # self.rotToRadCoeff = rotToRadCoeff
        self.maxTransSpeed = maxTransSpeed
        # self.transToTransCoeff = transToTransCoeff
        self.roverStates = []

    def initialize(self):
        print "Initializing Rover Module..."

        # Set up basics
        Rover20.__init__(self)
        self.wname = 'Rover 2.0: Hit ESC to quit'
        self.quit = False

        # Set up controller using PyGame
        pygame.display.init()
        pygame.joystick.init()
        print "Initializing Joystick..."
        self.controller = pygame.joystick.Joystick(0)
        self.controller.init()

         # Defaults on startup: lights off, ordinary camera
        self.lightsAreOn = False
        self.stealthIsOn = False

        # Tracks button-press times for debouncing
        self.lastButtonTime = 0

        # Try to create OpenCV named window
        # print "Creating OpenCV Window..."
        # try:
        #     if cv:
        #         cv.NamedWindow(self.wname, cv.CV_WINDOW_AUTOSIZE )
        #     else:
        #         pass
        # except:
        #     pass

        self.pcmfile = open('rover20.pcm', 'w')

    def getRoverStateCount(self):
        #print "[Python] Count of rover frames = " + str(len(self.roverStates))
        return len(self.roverStates)

    def getRoverState(self):
        return self.roverStates.pop(0)

    # Automagically called by Rover class
    def processAudio(self, pcmsamples, timestamp_10msec):
        for samp in pcmsamples:
            self.pcmfile.write('%d\n' % samp)

    # Automagically called by Rover class
    def processVideo(self, jpegbytes, timestamp_10msec):
        # Update controller events
        pygame.event.pump()

        # Toggle lights
        self.lightsAreOn  = self.checkButton(self.lightsAreOn, BUTTON_LIGHTS, self.turnLightsOn, self.turnLightsOff)

        # Toggle night vision (infrared camera)
        self.stealthIsOn = self.checkButton(self.stealthIsOn, BUTTON_STEALTH, self.turnStealthOn, self.turnStealthOff)
        # Move camera up/down
        # if self.controller.get_button(BUTTON_CAMERA_UP):
        #     self.moveCameraVertical(1)
        # elif self.controller.get_button(BUTTON_CAMERA_DOWN):
        #     self.moveCameraVertical(-1)
        # else:
        #     self.moveCameraVertical(0)

        # time.sleep(0.1)
        # Push the current rover state
        if hasattr(self, "curRoverState"):
            self.curRoverState.setEndTime(time.time())
            # Override image
            self.curRoverState.setImage(jpegbytes)
            # Add state
            self.roverStates.append(self.curRoverState)

        # Create a new state with the current image
        self.curRoverState = RoverState()
        print self.axis(0), self.axis(1), self.axis(2), self.axis(3)
        trans = self.axis(1)
        rot = -self.axis(0) #Direction modifier
        # We're moving
        if abs(trans) > self.deadZoneNorm or abs(rot) > self.deadZoneNorm:
            if abs(trans) > abs(rot):
                # Translation
                trans = self.maxTransSpeed * trans
                rot = 0
            else:
                # Rotation
                trans = 0
                rot = self.maxRotSpeed * rot
        else:
            # Neither
            trans = 0
            rot = 0
        self.setTreads(trans + rot, trans - rot) # Simple mixing because i'm lazy okay :)
        self.curRoverState.setRotAndTrans(rot, trans)

        # Now that we're moving, let's clean up buffer overflows
        if len(self.roverStates) >= 50:
            print "[Python] Warning - dropping frames!"
            self.roverStates.pop(0)


    # Converts Y coordinate of specified axis to +/-1 or 0
    def axis(self, index):

        value = -self.controller.get_axis(index)

        if value > MIN_AXIS_ABSVAL:
            return 1
        elif value < -MIN_AXIS_ABSVAL:
            return -1
        else:
            return value


    # Handles button bounce by waiting a specified time between button presses
    def checkButton(self, flag, buttonID, onRoutine=None, offRoutine=None):
        if self.controller.get_button(buttonID):
            if (time.time() - self.lastButtonTime) > MIN_BUTTON_LAG_SEC:
                self.lastButtonTime = time.time()
                if flag:
                    if offRoutine:
                        offRoutine()
                    flag = False
                else:
                    if onRoutine:
                        onRoutine()
                    flag = True
        return flag
