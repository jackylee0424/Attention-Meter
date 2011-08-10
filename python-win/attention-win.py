#! /usr/bin/env python

#########################################################
# attention-win.py
# Using OpenCV and CVtypes
#
# Jackie Lee
# jackylee@media.mit.edu
#
# Affective Computing Group, MIT Media Laboratory
# Special Thanks to Heymian Wong, Jon Wetzel
# Last modified on Aug. 9, 2011
#########################################################

import sys
import time
import os
from CVtypes import cv

### Face detection constants
#Face movement constants
CAPTURING = 0 ## set 1 to enable saving to JPGs
FACE_MIN_SIZE = 70 ## the bigger, the more fps
FACE_MAX_MOVEMENT = 40
FACE_MAX_LIFE = 1
FACE_LR_MOVE_THRESH = 2
FACE_UD_MOVE_THRESH = 1
FACE_LR_STATE_CHANGE_THRESH = 1
FACE_UD_STATE_CHANGE_THRESH = 1
FACE_ALTERNATION_THRESH = 2
FACE_ONE_DIMENSION_THRESH = 2
FACE_STILL_THRESHOLD = 3
FACE_ALTERNATIONS_EXPIRE = 6

#Face movement enumeration
OTHER = 0
STILL = 1
LEFT = 2
RIGHT = 3
UP = 4
DOWN = 5

#Color donstant definitions
RED = cv.RGB(255,0,0)
GREEN = cv.RGB (0,220,0)
BLUE = cv.RGB (0,0,255)
YELLOW = cv.RGB(255,255,0);
ORANGE = cv.RGB(255,127,0);
MAGENTA = cv.RGB(255,0,255);

# other constants
scale = 1
cascade = None
storage = cv.CreateMemStorage(0)
cascade_name = "xml/haarcascade_frontalface_alt.xml"
min_size = cv.Size(FACE_MIN_SIZE,FACE_MIN_SIZE) 
image_scale = 1.3
haar_scale = 1.2
min_neighbors = 2
haar_flags = cv.HAAR_DO_CANNY_PRUNING
age = 0
trackedFaces = []
IPL_DEPTH_8U = 8
gray = 0
small_img = 0
osName = os.name
fname_temp=""
### end of Face detection constants

### save as JPG for every 2 seconds
def saveAsJPG(img):
    global fname_temp
    lt = time.localtime(time.time())
    if ((lt[5] %2) == 0):
        fname =  "%04d%02d%02d%02d%02d%02d" % (lt[0], lt[1], lt[2], lt[3], lt[4], lt[5])
        if (fname != fname_temp):
            print "frame saved at " + fname
            cv.SaveImage("img/"+fname+".jpg",img)
            fname_temp = fname
### end save as JPG

########## Face Class #############
class Face:
    def __init__(self,age,width,height,xpt, ypt,life):
        self.age = age;
        self.width = width;
        self.height = height;
        self.xpt = xpt;
        self.ypt = ypt;
        self.life = life;
        self.updateEyes();
        self.updateMouth();
        
        self.state = OTHER;
        self.lastState = self.state;
        self.alternations = 0;
        self.faceStill = 0;
        
        self.stills = 0;
        self.lefts = 0;
        self.rights = 0
        self.ups = 0;
        self.downs = 0;
    def updateFace(self, width, height, xpt, ypt):
        turnDir = self.getTurnDir(self.xpt, xpt, self.ypt, ypt, self.width, width, self.height, height)
        self.updateMoveState(turnDir)
        #print turnDir
        
        self.age = self.age + 1;
        self.width = width;
        self.height = height;
        self.xpt = xpt;
        self.ypt = ypt;
        self.life = 0;
        self.updateEyes();
        self.updateMouth();
        
    def updateEyes(self):
        self.eyeTopline = self.ypt + ((self.height*1)/3);
        self.eyeBotline = self.ypt + ((self.height*1)/2);
        
        self.eyeLeft1 = cv.Point(self.xpt + (self.width/5),self.eyeTopline);
        self.eyeLeft2 = cv.Point(self.xpt + ((self.width*3)/8), self.eyeBotline);
        self.eyeRight1 = cv.Point(self.xpt + ((self.width*5)/8),self.eyeTopline);
        self.eyeRight2 = cv.Point(self.xpt + ((self.width*4)/5),self.eyeBotline);
    def updateMouth(self):
        self.mouthTopline = self.ypt + ((self.height*2)/3);
        self.mouthBotline = self.ypt + self.height;

        self.mouthTopLeft = cv.Point(self.xpt + self.width/5, self.mouthTopline);
        self.mouthBotRight = cv.Point(self.xpt + (self.width*4)/5, self.mouthBotline);

    def isShaking(self):
        if (self.alternations < FACE_ALTERNATION_THRESH):
            return False
        else:
            if ((self.state == LEFT) or (self.state == RIGHT)):
                return True
            else:
                return False
    def isNodding(self):
        if (self.alternations < FACE_ALTERNATION_THRESH):
            return False
        else:
            if ((self.state == UP) or (self.state ==DOWN)):
                return True
            else:
                return False
    def isStill(self):
        return (self.faceStill < FACE_STILL_THRESHOLD)
    
    def updateMoveState(self, turnDir):
        if (turnDir == OTHER):
            self.faceStill += 1
            self.state = OTHER
        elif (turnDir == STILL):
            if (self.state != STILL):
                lastState = self.state
            else:
                self.faceStill = 0
            self.state = STILL
            self.stills += 1
            if (self.stills > FACE_ALTERNATIONS_EXPIRE):
                self.alternations = 0
                self.stills = 0
        elif (turnDir == RIGHT):
            self.faceStill += 1
            if (self.state == OTHER):
                self.rights += 1
                if (self.rights > FACE_LR_STATE_CHANGE_THRESH):
                    self.state = RIGHT
            elif (self.state == RIGHT):
                self.rights += 1
            elif (self.state == LEFT):
                self.rights += 1
                if (self.rights > FACE_LR_STATE_CHANGE_THRESH):
                    self.state = RIGHT;
                    self.resetNonAltCounts()
                    self.alternations += 1
            elif ((self.state == UP) or (self.state == DOWN)):
                self.state = OTHER
                self.resetCounts()
            elif(self.state == STILL):
                if (self.lastState == LEFT):
                    self.alternations += 1
                self.state = RIGHT
        elif (turnDir ==LEFT):
            self.faceStill += 1
            if (self.state == OTHER):
                self.lefts += 1
                if (self.lefts > FACE_LR_STATE_CHANGE_THRESH):
                    self.state = LEFT;
            elif (self.state == RIGHT):
                self.lefts += 1
                if(self.lefts > FACE_LR_STATE_CHANGE_THRESH):
                    self.state = LEFT
                    self.resetNonAltCounts()
                    self.alternations += 1
            elif (self.state == LEFT):
                self.lefts += 1
            elif ((self.state ==UP) or (self.state == DOWN)):
                self.state = OTHER
                self.resetCounts()
            elif (self.state == STILL):
                if (self.lastState == RIGHT):
                    self.alternations += 1
                self.state = LEFT
        elif (turnDir == UP):
            self.faceStill += 1
            if (self.state == OTHER):
                self.ups += 1
                if (self.ups > FACE_UD_STATE_CHANGE_THRESH):
                    self.state = UP
            elif (self.state == DOWN):
                self.ups += 1
                if (self.ups > FACE_UD_STATE_CHANGE_THRESH):
                    self.state = UP
                    self.resetNonAltCounts()
                    self.alternations += 1
            elif (self.state == UP):
                self.ups += 1
            elif ((self.state == LEFT) or (self.state == RIGHT)):
                self.state = OTHER
                self.resetCounts()
            elif (self.state == STILL):
                if (self.lastState == DOWN):
                    self.alternations += 1
                self.state = UP
        elif (turnDir == DOWN):
            self.faceStill += 1
            if (self.state == OTHER):
                self.downs += 1
                if (self.downs > FACE_UD_STATE_CHANGE_THRESH):
                    self.state = DOWN
            elif (self.state == UP):
                self.downs += 1
                if (self.downs > FACE_UD_STATE_CHANGE_THRESH):
                    self.state = DOWN
                    self.resetNonAltCounts()
                    self.alternations += 1
            elif (self.state == DOWN):
                self.downs += 1
            elif ((self.state == LEFT) or (self.state == RIGHT)):
                self.state = OTHER
                self.resetCounts()
            elif (self.state == STILL):
                if (self.lastState == UP):
                    self.altnerations += 1
                self.state = DOWN
        
    def resetCounts(self):
        self.others = 0
        self.stills = 0
        self.rights = 0
        self.lefts = 0
        self.ups = 0
        self.downs = 0
        self.alternations = 0
    def resetNonAltCounts(self):
        self.others = 0
        self.stills = 0
        self.rights = 0
        self.lefts = 0
        self.ups = 0
        self.downs = 0
    def getTurnDir(self, old_xpt, new_xpt, old_ypt, new_ypt, old_width, new_width, old_height, new_height):
        old_x = (int (old_xpt + (old_width/2)))
        new_x = (int (new_xpt + (new_width/2)))
        old_y = (int (old_ypt + (old_height/2)))
        new_y = (int (new_ypt + (new_height/2)))

        xdir = STILL
        ydir = STILL
        if (new_x - old_x > FACE_LR_MOVE_THRESH):
            xdir = RIGHT
        if (new_x - old_x < -FACE_LR_MOVE_THRESH):
            xdir = LEFT
        if (new_y - old_y > FACE_UD_MOVE_THRESH):
            ydir = DOWN
        if (new_y - old_y < -FACE_UD_MOVE_THRESH):
            ydir = UP
        if (ydir == xdir):
            return STILL
        else:
            if ((ydir != STILL) and (xdir !=STILL)):
                if ((abs(new_x - old_x)) > (abs(new_y - old_y)/2)):
                    return xdir
                else:
                    if (((abs(new_y - old_y)) - (abs(new_x - old_x))) > FACE_ONE_DIMENSION_THRESH):
                        return ydir
                    else:
                        return OTHER;
            else:
                if (xdir == STILL):
                    return ydir
                else:
                    return xdir

    def isTooOld(self):
        if (self.life > FACE_MAX_LIFE):
            return True;
        else:
            return False;
    def updateLife(self):
        self.life = self.life+1;
        return self.life;
########## end of Face Class #############

#### Detect faces ######################
def detect_and_draw(img ,cascade):
    global age
    global trackedFaces
    global plotpoints

    t = cv.GetTickCount() ## start counter    
    cv.CvtColor( img, gray, cv.BGR2GRAY )
    cv.Resize( gray, small_img, cv.INTER_LINEAR )
    cv.ClearMemStorage( storage )

    #Ages all trackedFaces
    for f in trackedFaces:
        f.updateLife()
    #Remove expired faces
    for f in trackedFaces:
        if (f.isTooOld()):
            trackedFaces.remove(f)
    
    faces = cv.HaarDetectObjects( small_img, cascade, storage, haar_scale, min_neighbors, haar_flags, min_size )
    drawline = 0
    if faces:
        #found a face
        for r in faces:
            matchedFace = False;
            pt1 = cv.Point( int(r.x*image_scale), int(r.y*image_scale))
            pt2 = cv.Point( int((r.x+r.width)*image_scale), int((r.y+r.height)*image_scale) )
            
            #check if there are trackedFaces
            if (len(trackedFaces) > 0):
                #each face being tracked
                for f in trackedFaces:
                    #the face is found (small movement)
                    if ((abs(f.xpt - pt1.x) < FACE_MAX_MOVEMENT) and (abs(f.ypt - pt1.y) < FACE_MAX_MOVEMENT)):
                        matchedFace = True;
                        f.updateFace(int(r.width*image_scale), int(r.height*image_scale), pt1.x, pt1.y);
                        #f.updateFace(r.width*image_scale, r.height*image_scale, pt1.x, pt1.y);
                        mf = f;
                        break;
                        
                #if face not found, add a new face
                if (matchedFace == False):
                    f = Face(0,int(r.width*image_scale), int(r.height*image_scale), pt1.x, pt1.y,0);
                    trackedFaces.append(f);
                    mf = f;
            #No tracked faces: adding one                            
            else:
                f = Face(0,int (r.width*image_scale), int (r.height*image_scale), pt1.x, pt1.y,0);
                trackedFaces.append(f);
                mf = f;
            #where to draw face and properties
            if (mf.age > 5):
                #draw attention line
                lnpt1 = cv.Point (int (mf.xpt*scale), int(mf.ypt*scale-5)-5)
                if (mf.age > mf.width):
                    lnpt2 = cv.Point (int (mf.xpt*scale+mf.width), int(mf.ypt*scale-5))
                else:
                    lnpt2 = cv.Point (int (mf.xpt*scale+mf.age), int(mf.ypt*scale-5))
                #cv.Line(img, lnpt1, lnpt2, RED, 2, 8, 0) ## drawing attention line
                cv.Rectangle(img, lnpt1, lnpt2, RED, 4, 8, 0) ## drawing bolded attention line
                
                ### draw eyes
                cv.Rectangle(img, mf.eyeLeft1, mf.eyeLeft2, MAGENTA, 3,8,0)
                cv.Rectangle(img, mf.eyeRight1, mf.eyeRight2, MAGENTA, 3,8,0)
                #
                ### draw mouth
                cv.Rectangle(img, mf.mouthTopLeft, mf.mouthBotRight, ORANGE, 3, 8, 0)
                #
                ### draw face
                cv.Rectangle( img, pt1, pt2, getColor(mf), 3, 8, 0 )
                drawline = mf.age
                
    if(CAPTURING): saveAsJPG(img) 
    if (osName == "nt"): cv.Flip(img, img, 0)
    cv.ShowImage ('Camera', img)
    t = cv.GetTickCount() - t ## counter for FPS
    print "%i fps." % (cv.GetTickFrequency()*1000000./t) ## print FPS
#### end of Detect faces ######################

def getColor(mf):
    if (mf.isNodding()): return GREEN
    elif (mf.isShaking()): return RED
    elif (mf.isStill()): return BLUE
    else: return YELLOW
        
######### main program ############
if __name__ == '__main__':
    print "OpenCV in Python using CVtypes"
    print "OpenCV version: %s (%d, %d, %d)" % (cv.VERSION,cv.MAJOR_VERSION,cv.MINOR_VERSION,cv.SUBMINOR_VERSION)

    #create window and move to screen position
    cv.NamedWindow ('Camera', cv.WINDOW_AUTOSIZE)
    if len (sys.argv) == 1:
        # no argument on the command line, try to use the camera
        capture = cv.CreateCameraCapture (0)
    #
    ### check that capture device is OK
    if not capture:
        print "Error opening capture device"
        sys.exit (1)
    #
    ### capture the 1st frame to get some propertie on it
    frame = cv.QueryFrame (capture)
    #
    ### get size of the frame
    frame_size = cv.GetSize (frame)
    gray = cv.CreateImage( frame_size, 8, 1 )
    small_img = cv.CreateImage( cv.Size( int(frame_size.width/image_scale),int(frame_size.height/image_scale)), 8, 1 )
    cascade = cv.LoadHaarClassifierCascade( cascade_name, cv.Size(1,1) )
    #   
    while 1: # do forever
        # capture the current image
        frame = cv.QueryFrame (capture)
        if frame is None:
            # no image captured... end the processing
            break
        #
        ### check OS
        if (osName == "nt"):
            cv.Flip(frame, frame, 0)
        else:
            cv.Flip(frame, None, 1)
        #
        ### detecting faces here
        detect_and_draw(frame, cascade)
        #
        ### handle key events
        k = cv.WaitKey (5)
        if k % 0x100 == 27:
            # user has press the ESC key, so exit
            cv.DestroyWindow('Camera');
            break
