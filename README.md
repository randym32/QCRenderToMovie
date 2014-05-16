QCRenderToMovie
====================

This is an application that can make a movie from a  Quartz Composer composition.


Command Line
----------------

	QuartzComposerOffline _sourceComposition_ _destinationFolder_


Limitations
------------
There isn't an audio channel.


Requirements
---------------
The plugin was created using the Xcode editor running under Mac OS X 10.8.x or later. 


Note
-----
I'm sure that that "pixel buffers" is not most efficient mechanism.  IOSurfaces or other might be
good.  However, I am not sure how to accomplish that.