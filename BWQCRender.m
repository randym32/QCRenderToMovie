//
//  BWQCRender.m
//  QuartzComposerOffline
//  Copyright (c) 2014, Randall Maas
//
//  Created by Randall Maas on 1/7/14.
//  Bits based on Apple Sample code
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

// TODO  framebuffer renderng!

#import "BWQCRender.h"
#import <AVFoundation/AVAssetWriter.h>
#import <AVFoundation/AVAssetWriterInput.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVVideoSettings.h>

#define TimeBase (600 * 100000)
#define TimedT   (TimeBase/30)

@implementation BWQCRender

- (id) init
{
	return [self initWithCompositionPath: nil
                                    size: CGSizeMake(0,0)
                                     out: nil];
}

- (id) initWithCompositionPath:(NSString*) path
                          size:(CGSize)    size
                           out:(NSString*) outPath
{
    NSOpenGLPixelFormatAttribute	attributes[] =
        {
            NSOpenGLPFAAccelerated, NSOpenGLPFANoRecovery, NSOpenGLPFADoubleBuffer, NSOpenGLPFADepthSize, 24, 0
        };
    //Create the OpenGL context used to render the animation and attach it to the rendering view
    NSOpenGLPixelFormat* glPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    NSOpenGLContext* glContext = [[NSOpenGLContext alloc] initWithFormat: glPixelFormat
                                                            shareContext: nil];
    self = [self initWithCompositionPath: path
                                    size: size
                                     out: outPath
                           openGLContext: glContext];
    [glContext release];
    [glPixelFormat release];
    return self;
}


- (id) initWithCompositionPath:(NSString*) path
                          size:(CGSize)    size
                           out:(NSString*) outPath
                 openGLContext:(NSOpenGLContext*)context
{
    // Have the parent initialize, and bail if there was a problem
	if(!(self = [super init]))
    {
        // The parent didn't initialize, so quit
        return nil;
    }
    

	// Check parameters - Rendering at sizes smaller than 16x16 will likely produce garbage
	if (  ![path length]
        || ![outPath length]
        || (size.width < 16)
        || (size.height < 16)
        || !context
        )
    {
    err:
        // There was an error, so clean up and return
		[self release];
		return nil;
	}

    //Keep the target OpenGL context around
    _textureContext = [context retain];
    
    // Load the composition
	//IMPORTANT: We use the macros provided by <OpenGL/CGLMacro.h> which provide better performances and allows us not to bother with making sure the current context is valid
	CGLContextObj					cgl_ctx = [_textureContext CGLContextObj];
	NSOpenGLPixelFormatAttribute	attributes[] =
    {
        NSOpenGLPFAPixelBuffer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADepthSize, 24,
        (NSOpenGLPixelFormatAttribute) 0
    };
	NSOpenGLPixelFormat*			format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
	GLint							saveTextureName;
    
    //Create the OpenGL pBuffer to render into
    // Could be GL_TEXTURE_RECTANGLE_EXT instead of GL_TEXTURE_2D
    _pixelBuffer = [[NSOpenGLPixelBuffer alloc] initWithTextureTarget: GL_TEXTURE_2D
                                                textureInternalFormat: GL_RGBA
                                                textureMaxMipMapLevel: 0
                                                           pixelsWide: size.width
                                                           pixelsHigh: size.height];
    if (!_pixelBuffer)
    {
        NSLog(LogPrefix @"Cannot create OpenGL pixel buffer");
        goto err;
    }
    
    //Create the OpenGL context to use to render in the pBuffer (with color and depth buffers) - It needs to be shared to ensure both contexts have identical virtual screen lists
    _pixelBufferContext = [[NSOpenGLContext alloc] initWithFormat:format
                                                     shareContext:_textureContext];
    if (!_pixelBufferContext)
    {
        NSLog(LogPrefix @"Cannot create OpenGL context");
        goto err;
    }
    
    //Attach the OpenGL context to the pBuffer (make sure it uses the same virtual screen as the primary OpenGL context)
    [_pixelBufferContext setPixelBuffer:_pixelBuffer
                            cubeMapFace:0
                            mipMapLevel:0
                   currentVirtualScreen:[_textureContext currentVirtualScreen]];
    
    //Create the QuartzComposer Renderer with that OpenGL context and the specified composition file
    _renderer = [[QCRenderer alloc] initWithOpenGLContext:_pixelBufferContext
                                              pixelFormat:format
                                                     file:path];
    if(_renderer == nil)
    {
        NSLog(LogPrefix @"Cannot create QCRenderer");
        goto err;
    }
    
    //Create the texture on the target OpenGL context
    glGenTextures(1, &_textureName);
    
    //Configure the texture - For extra safety, we save and restore the currently bound texture
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &saveTextureName);
    glBindTexture(GL_TEXTURE_2D, _textureName);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glBindTexture(GL_TEXTURE_2D, saveTextureName);
    
    //Update the texture immediately
    [self updateTextureForTime:0.0];

    NSError* localError;
    avWriter = [[AVAssetWriter alloc] initWithURL: [NSURL fileURLWithPath:outPath]
                                         fileType: AVFileTypeAppleM4V
                                            error:&localError];
    
    // Compress to H.264 with the asset writer
    avInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                  outputSettings:
                @{
                  AVVideoCodecKey : AVVideoCodecH264,
                  AVVideoWidthKey : [NSNumber numberWithDouble:size.width],
                  AVVideoHeightKey: [NSNumber numberWithDouble:size.height],
#if 0
                  AVVideoCompressionPropertiesKey:
                    @{
                      AVVideoAverageBitRateKey:[NSNumber numberWithInt:8000000],
                      AVVideoMaxKeyFrameIntervalKey:[NSNumber numberWithInt:1]
                    }
#endif
                  }] retain];
    [avWriter addInput:avInput];
    // kCVPixelFormatType_422YpCbCr8
    avAdaptor = [[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput: avInput
                                                                                  sourcePixelBufferAttributes:
                  @{
                    (NSString*)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithInt:kCVPixelFormatType_32ARGB]
                    }] retain];
    
    // add input
    [avWriter startWriting];
    [avWriter startSessionAtSourceTime:CMTimeMake(0, TimeBase)];
    _size = size;
    
    
    dispatchQueue = dispatch_queue_create("mediaInputQueue", NULL);

    return self;
}


- (void) dealloc
{
    if (dispatchQueue)
        dispatch_release(dispatchQueue);
    [avInput markAsFinished];
    [avWriter finishWriting];
    [avAdaptor release];
    [avInput   release];
    [avWriter  release];
    // Destroy the OpenGL context
	[_pixelBufferContext clearDrawable];
	[_pixelBufferContext release];
    _pixelBufferContext = nil;
	
	// Destroy the OpenGL pixel buffer
	[_pixelBuffer release];
    _pixelBuffer = nil;
	// Destroy the renderer
	[_renderer release];

    //IMPORTANT: We use the macros provided by <OpenGL/CGLMacro.h> which provide better performances and allows us not to bother with making sure the current context is valid
	CGLContextObj					cgl_ctx = [_textureContext CGLContextObj];
	
	//Destroy the texture on the target OpenGL context
	if(_textureName)
        glDeleteTextures(1, &_textureName);
    
    //Release target OpenGL context
	[_textureContext release];

	[super dealloc];
}



/** Renders the given number of frames
    @param numFrames The number of frames to render
    @return true on success, false on error
 */
- (bool) renderFrames:(int) numFrames
{
    while (frame < numFrames)
    {
        while (![avInput isReadyForMoreMediaData])
            usleep(0);
        if (![self render])
            break;
    }

#if 0
    // Make a note to indate that we are done
    NSLog(LogPrefix @"outside for loop: %u", frame);
#endif
    return true;
}


/** Renders the next frame
    @return true on success, false on error
 */
- (bool) render
{
    // Compute the time numerator
    int64_t itime = (1+frame) * (int64_t)TimedT;
    
    // Render the frame for the time
    bool ret = [self renderForTime: itime];

    // Check that the frame was updated
    if (ret)
    {
        // Update the frame count
        frame++;
    }
    else
    {
        // There an error rendering the frame
        NSLog(LogPrefix @"FAIL: %@", avWriter.error);
    }
    
    // Return the result
    return ret;
}


/** Render the frame at the given time point and send it to the file
    @param timeNumerator  The point in time (relative to the time base)
    @return true on success, false on error
 */
- (bool) renderForTime: (int64_t) timeNumerator
{
    // Figure out the current time
    double time = timeNumerator / (double) TimeBase;
    bool ret;

	//Render a frame from the composition at the specified time
    ret = [self updateTextureForTime: (NSTimeInterval) time];
    if (!ret)
        return NO;

    // Grab a snapshot of rendered image
    CVPixelBufferRef buffer = (CVPixelBufferRef) [_renderer createSnapshotImageOfType:@"CVPixelBuffer"];
    if (!buffer)
        return NO;

    // Send the buffer into the output
    ret = [avAdaptor appendPixelBuffer: buffer
                  withPresentationTime: CMTimeMake(timeNumerator, TimeBase)];
    CFRelease(buffer);
    return ret;
}


/** @brief Have the patch update the texture
    @param time  The interval to move by
    @returns NO if the buffer wasn't updated; YES if the buffer was updated
  */
- (BOOL) updateTextureForTime: (NSTimeInterval)time
{
	//IMPORTANT: We use the macros provided by <OpenGL/CGLMacro.h> which provide better performances and allows us not to bother with making sure the current context is valid
	CGLContextObj					cgl_ctx = [_pixelBufferContext CGLContextObj];
	BOOL							success;
	GLenum							error;
	NSOpenGLPixelBuffer*			pBuffer;
	
	//Make sure the virtual screen for the pBuffer and its rendering context match the target one
	if ([_textureContext currentVirtualScreen] != [_pixelBufferContext currentVirtualScreen])
    {
        NSLog(LogPrefix @"The virtual screens no longer match.. this is weird!");

        // Allocate the buffer
		pBuffer = [[NSOpenGLPixelBuffer alloc] initWithTextureTarget: GL_TEXTURE_2D
                                               textureInternalFormat: GL_RGBA
                                               textureMaxMipMapLevel: 0
                                                          pixelsWide: [_pixelBuffer pixelsWide]
                                                          pixelsHigh: [_pixelBuffer pixelsHigh]];
		if (!pBuffer)
        {
            // There wasn't a buffer allocated.
			NSLog(LogPrefix @"Failed recreating OpenGL pixel buffer");
			return NO;
		}

        // Clear the buffer
        [_pixelBufferContext clearDrawable];
        [_pixelBuffer release];
        _pixelBuffer = pBuffer;
        [_pixelBufferContext setPixelBuffer: _pixelBuffer
                                cubeMapFace: 0
                                mipMapLevel: 0
                       currentVirtualScreen: [_textureContext currentVirtualScreen]];
	}
	
	// Render a frame from the composition at the specified time in the pBuffer
	success = [_renderer renderAtTime: time
                            arguments: nil];

	// IMPORTANT: Make sure all OpenGL rendering commands were sent to the pBuffer OpenGL context
	glFlushRenderAPPLE();

	// Check for errors
	if ((error = glGetError()))
    {
        NSLog(LogPrefix @"OpenGL error 0x%04X", error);
    }

	// Return the result
	return success;
}


@end
