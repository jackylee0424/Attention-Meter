#########################################################################################
#
#  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.
#
#  By downloading, copying, installing or using the software you agree to this license.
#  If you do not agree to this license, do not download, install,
#  copy or use the software.
#
#
#                        Intel License Agreement
#                For Open Source Computer Vision Library
#
# Copyright (C) 2000, Intel Corporation, all rights reserved.
# Third party copyrights are property of their respective owners.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#   * Redistribution's of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#
#   * Redistribution's in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#
#   * The name of Intel Corporation may not be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
# This software is provided by the copyright holders and contributors "as is" and
# any express or implied warranties, including, but not limited to, the implied
# warranties of merchantability and fitness for a particular purpose are disclaimed.
# In no event shall the Intel Corporation or contributors be liable for any direct,
# indirect, incidental, special, exemplary, or consequential damages
# (including, but not limited to, procurement of substitute goods or services;
# loss of use, data, or profits; or business interruption) however caused
# and on any theory of liability, whether in contract, strict liability,
# or tort (including negligence or otherwise) arising in any way out of
# the use of this software, even if advised of the possibility of such damage.
#
#########################################################################################


# 2004-03-16, Mark Asbach       <asbach@ient.rwth-aachen.de>
#             Institute of Communications Engineering, RWTH Aachen University


"""
This module provides explicit conversion methods for
    - CvMat:  OpenCV / IPL image data
    - PIL:       Python Imaging Library
    - Numeric:   Python's Numeric Library

Currently supported image formats are:
    - 3 x  8 bit  RGB (GBR)
    - 1 x  8 bit  Grayscale
    - 1 x 32 bit  Float

In Numeric, images are represented as multidimensional arrays with
a third dimension representing the image channels if more than one
channel is present.
"""

import cv
import PIL
import PIL.Image
import Numeric

###########################################################################
def Ipl2PIL(input):
    """Converts an OpenCV/IPL image to PIL the Python Imaging Library.
    
    Supported input image formats are
       IPL_DEPTH_8U  x 1 channel
       IPL_DEPTH_8U  x 3 channels
       IPL_DEPTH_32F x 1 channel
    """
    
    if not isinstance(input, cv.CvMat):
        raise TypeError, 'must be called with a cv.CvMat!'

    # assert that the channels are interleaved
    if input.dataOrder != 0:
        raise ValueError, 'dataOrder must be 0 (interleaved)!'

    #orientation
    if input.origin == 0:
        orientation = 1 # top left
    elif input.origin == 1:
        orientation = -1 # bottom left
    else:
        raise ValueError, 'origin must be 0 or 1!'

    # mode dictionary:
    # (channels, depth) : (source mode, dest mode, depth in byte)
    mode_list = {
        (1, cv.IPL_DEPTH_8U)  : ("L", "L", 1),
        (3, cv.IPL_DEPTH_8U)  : ("BGR", "RGB", 3),
        (1, cv.IPL_DEPTH_32F) : ("F", "F", 4)
        }

    key = (input.nChannels, input.depth)
    if not mode_list.has_key(key):
        raise ValueError, 'unknown or unsupported input mode'
        
    modes = mode_list[key]

    return PIL.Image.fromstring(
        modes[1], # mode
        (input.width, input.height), # size tuple
        input.imageData, # data
        "raw",
        modes[0], # raw mode
        input.widthStep, # stride
        orientation # orientation
        )


###########################################################################
def PIL2Ipl(input):
    """Converts a PIL image to the OpenCV/IPL CvMat data format.
    
    Supported input image formats are:
        RGB
        L
        F
    """
    
    if not isinstance(input, PIL.Image.Image):
       raise TypeError, 'must be called with PIL.Image.Image!'

    size = cv.cvSize(input.size[0], input.size[1])
    
    # mode dictionary:
    # (pil_mode : (ipl_depth, ipl_channels, color model, channel Seq)
    mode_list = {
        "RGB" : (cv.IPL_DEPTH_8U, 3),
        "L"   : (cv.IPL_DEPTH_8U, 1),
        "F"   : (cv.IPL_DEPTH_32F, 1)
        }
    
    if not mode_list.has_key(input.mode):
        raise ValueError, 'unknown or unsupported input mode'
        
    modes = mode_list[input.mode]    
    
    result = cv.cvCreateImage(
        size,
        modes[0], # depth
        modes[1]  # channels
        )
    
    # set imageData
    result.imageData=input.tostring()
    
    return result    
 
    
###########################################################################
def PIL2NumPy(input):
    """Converts a PIL image to a Numeric array.
    
    Supported input image formats are:
        RGB
        L
        F
    """
    
    if not isinstance(input, PIL.Image.Image):
        raise TypeError, 'must be called with PIL.Image.Image!'
        
    # mode dictionary:
    # (pil_mode : (Numeric typecode, channels)
    mode_list = {
        "RGB" : (Numeric.UnsignedInt8, 3),
        "L"   : (Numeric.UnsignedInt8, 1),
        "F"   : (Numeric.Float32, 1)
        }
    
    if not mode_list.has_key(input.mode):
        raise ValueError, 'unknown or unsupported input mode'
    
    modes = mode_list[input.mode]    
    
    if modes[1]>1:
        shape = (input.size[1], input.size[0], modes[1])
    else:
        shape = (input.size[1], input.size[0])
    
    result = Numeric.array_constructor(
        shape,
        modes[0],
        input.tostring()
        )

    return result


###########################################################################
def NumPy2PIL(input):
    """Converts a Numeric array to a PIL image.
    
    Supported input array layouts:
       2 dimensions of Numeric.UnsignedInt8
       3 dimensions of Numeric.UnsignedInt8
       2 dimensions of Numeric.Float32
    """
    
    if not isinstance(input, Numeric.arraytype):
        raise TypeError, 'must be called with Numeric.array!'
        
    # mode dictionary:
    # (channels, typecode) : (source mode, dest mode, depth in byte)
    mode_list = {
        (1, Numeric.UnsignedInt8)  : ("L",   "L"),
        (3, Numeric.UnsignedInt8)  : ("RGB", "RGB"),
        (1, Numeric.Float32)       : ("F",   "F")
        }

    channels = 1
    if Numeric.rank(input) == 3:
        channels = Numeric.shape(input)[2]
        
    key = (channels, input.typecode())
    if not mode_list.has_key(key):
        raise ValueError, 'unknown or unsupported input mode'
        
    modes = mode_list[key]

    return PIL.Image.fromstring(
        modes[1], # mode
        (Numeric.shape(input)[1], Numeric.shape(input)[0]), # size tuple
        input.tostring(), # data
        "raw",
        modes[0], # raw mode
        0, # stride
        1 # orientation
        )

 
###########################################################################
def NumPy2Ipl(input):
    """Converts a Numeric array to the OpenCV/IPL CvMat data format.
    
    Supported input array layouts:
       2 dimensions of Numeric.UnsignedInt8
       3 dimensions of Numeric.UnsignedInt8
       2 dimensions of Numeric.Float32
    """
    
    return PIL2Ipl(NumPy2PIL(input))


###########################################################################
def Ipl2NumPy(input):
    """Converts an OpenCV/IPL image to a Numeric array.
    
    Supported input image formats are
       IPL_DEPTH_8U  x 1 channel
       IPL_DEPTH_8U  x 3 channels
       IPL_DEPTH_32F x 1 channel
    """
    
    return PIL2NumPy(Ipl2PIL(input))


