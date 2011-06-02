//
//  JSONFetcher.m
//  CocoaWithLove
//
//  Created by Matt Gallagher on 2011/05/20.
//  Copyright 2011 Matt Gallagher. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

#import "MTJSONFetcher.h"
#import "JSONKit.h"

@implementation MTJSONFetcher

@synthesize result;

//
// close
//
// Cancel the connection and release all connection data. Does not release
// the result if already generated (this is only released when the class is
// released).
//
// Will send the response if the receiver is non-nil. But always releases the
// receiver when done.
//
- (void)close {
	[super close];
	
	[result release];
	result = nil;
}

//
// connectionDidFinishLoading:
//
// When the connection is complete, parse the JSON and reconstruct
//
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	// Parse the JSON
	result = [data objectFromJSONData];


#if TARGET_OS_IPHONE		
	if (result == nil && showAlerts) {
		UIAlertView *alert =
			[[UIAlertView alloc]
				initWithTitle:NSLocalizedStringFromTable(@"Connection Error", @"XMLFetcher", @"Title for error dialog")
				message:NSLocalizedStringFromTable(@"Server response was not understood.", @"XMLFetcher", @"Detail for an error dialog.")
				delegate:nil
				cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"XMLFetcher", @"Standard dialog dismiss button")
				otherButtonTitles:nil];
		[alert show];    
		[alert release];
	}
#endif
	
	[self close];
}

@end
