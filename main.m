/*
    File: main.m
    Copyright (c) 2014, Randall Maas
 
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

#import <libgen.h>
#import <AppKit/AppKit.h>
#import <OpenGL/CGLMacro.h>
#import "BWQCRender.h"

int main(int argc, const char* argv[])
{
	// Make sure we have the correct number of arguments
	if (argc < 3)
    {
        printf("Usage: %s sourceComposition destinationFolder\n", basename((char*)argv[0]));
        return 0;
    }
    chdir(dirname((char*)argv[1]));
    

    // A buffer to hold the intermediate objects
	NSAutoreleasePool*			pool = [NSAutoreleasePool new];
	NSBitmapImageRep*			bitmapImage;
	NSTimeInterval				time;
	NSData*						tiffData;
	NSString*					fileName;
	

    // Process the arguments
    NSString* compositionPath = [[NSString stringWithUTF8String:argv[1]] stringByStandardizingPath];
    NSString* outPath         = [[NSString stringWithUTF8String:argv[2]] stringByStandardizingPath];


    // Create an offline renderer
    // Note: the size is fixed
    BWQCRender* renderer = [[BWQCRender alloc] initWithCompositionPath: compositionPath
                                                                  size: CGSizeMake(1280, 720)
                                                                   out: outPath];
    if (renderer)
    {
        // Render the composition
        printf("Rendering composition \"%s\"...\n", [[compositionPath lastPathComponent] UTF8String]);
        [renderer renderFrames:30*71+13];
        printf("...done!\n");
        [renderer release];
    }
    else
    {
		NSLog(LogPrefix @"Offline renderer creation for composition failed (%@)", compositionPath);
    }
	
    // Release the autorelease pool
	[pool release];
	
	return 0;
}
