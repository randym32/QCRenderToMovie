//
//  BWQCRender.h
//  QuartzComposerOffline
//  Copyright (c) 2014, Randall Maas
//
//  Created by Randall Maas on 1/7/14.
/*
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/


#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>
@class AVAssetWriter;
@class AVAssetWriterInput;
@class AVAssetWriterInputPixelBufferAdaptor;

#define LogPrefix @"BWQCRender: "

/** This is a class to render Quartz Composer compositions to a quicktime movie
    -- I wonder if there is an update to the video frame that does a lot of the work
*/
@interface BWQCRender : NSObject
{
    /// This is the Quartz Composer renderr
	QCRenderer*					_renderer;

    /// This is just an the video writer
	AVAssetWriter				*avWriter;
    
    /// This is just an input stream in the asset writer.. kept only so that we can stop it
    AVAssetWriterInput*          avInput;
    
    /// This is used to take image buffers (eg from a view or image) and put them into the video
    /// stream
    AVAssetWriterInputPixelBufferAdaptor* avAdaptor;
    dispatch_queue_t    dispatchQueue;

	NSOpenGLPixelBuffer*		_pixelBuffer;
	NSOpenGLContext*			_pixelBufferContext;
    NSOpenGLContext*			_textureContext;
	GLuint						_textureName;

    /// The current frame that we are displaying
    uint __block frame;

    /// The size of the video area
    CGSize _size;
}


/** This is the designated initializer for the BWQCRender object
    @param path   The path to the Quartz Composer composition
    @param size   The width and height of the render area
    @param height The height of the render area
*/
- (id) initWithCompositionPath: (NSString*) path
                          size: (CGSize)    size
                           out: (NSString*) outPath;


/** Renders the given number of frames
    @param numFrames The number of frames to render
    @return true on success, false on error
 */
- (bool) renderFrames:(int) numFrames;
@end

