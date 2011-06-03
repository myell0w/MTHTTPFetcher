//
//  HTTPFetcher.m
//  FuelView
//
//  Created by Matt Gallagher on 2011/05/20.
//  Copyright 2011 Matt Gallagher. All rights reserved.
//

#import "MTHTTPFetcher.h"

@implementation MTHTTPFetcher

@synthesize data;
@synthesize urlRequest;
@synthesize failureCode;
@synthesize showAlerts;
@synthesize showAuthentication;
@synthesize responseHeaderFields;
@synthesize context;

//
// initWithURLString:receiver:action
//
// Init method for the object.
//
- (id)initWithURLRequest:(NSURLRequest *)aURLRequest
	receiver:(id)aReceiver
	action:(SEL)receiverAction
{
	self = [super init];
	if (self != nil)
	{
		action = receiverAction;
		receiver = aReceiver;
		urlRequest = [aURLRequest retain];
		showAlerts = YES;
		showAuthentication = YES;
		
		connection =
			[[NSURLConnection alloc]
				initWithRequest:aURLRequest
				delegate:self
				startImmediately:NO];
	}
	return self;
}

//
// initWithURLString:receiver:action:
//
// Convenience constructor that constructs the NSURLRequest from a string
//
// Parameters:
//    aURLString - the string from the URL
//    aReceiver - the receiver
//    receiverAction - the selector on the receiver
//
// returns the initialized object
//
- (id)initWithURLString:(NSString *)aURLString
	receiver:(id)aReceiver
	action:(SEL)receiverAction
{
	//
	// Create the URL request and invoke super
	//
	NSURL *url = [NSURL URLWithString:aURLString];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

	return [self initWithURLRequest:request receiver:aReceiver action:receiverAction];
}

//
// initWithURLString:timeout:cachePolicy:receiver:action:
//
// Convenience constructor that constructs the NSURLRequest and set the timeout
// and cache policy
//
// Parameters:
//    aURLString - the string from the URL
//    aTimeoutInterval - the timeout for the request
//    aCachePolicy - the cache policy (so no cache can be specified)
//    aReceiver - the receiver
//    receiverAction - the selector on the receiver
//
// returns the initialized object
//
- (id)initWithURLString:(NSString *)aURLString
	timeout:(NSTimeInterval)aTimeoutInterval
	cachePolicy:(NSURLCacheStoragePolicy)aCachePolicy
	receiver:(id)aReceiver
	action:(SEL)receiverAction
{
	//
	// Create the URL request and invoke super
	//
	NSURL *url = [NSURL URLWithString:aURLString];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setTimeoutInterval:aTimeoutInterval];
	[request setCachePolicy:aCachePolicy];

	return [self initWithURLRequest:request receiver:aReceiver action:receiverAction];
}

//
// start
//
// Start the connection
//
- (void)start
{
	[connection start];
}

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
- (void)close
{
	[connection cancel];
	[connection release];
	connection = nil;
	
	[challenge release];
	challenge = nil;
	
	[receiver performSelector:action withObject:self];
	receiver = nil;

	[data release];
	data = nil;
}

//
// cancel
//
// Sets the receiver to nil (so it won't receive a response and then closes the
// connection and frees all data.
//
- (void)cancel
{
	receiver = nil;
	[self close];
}

//
// connection:didReceiveResponse:
//
// When a start-of-message is received from the server, set the data to zero.
//
- (void)connection:(NSURLConnection *)aConnection
	didReceiveResponse:(NSHTTPURLResponse *)aResponse
{
	responseHeaderFields = [[aResponse allHeaderFields] retain];

	if ([aResponse statusCode] >= 400)
	{
		failureCode = [aResponse statusCode];
		
		NSString *errorMessage;
		if (failureCode == 404)
		{
			errorMessage =
				NSLocalizedStringFromTable(@"Requested file not found or couldn't be opened.", @"HTTPFetcher", @"Error given when a file cannot be opened or played.");
		}
		else if (failureCode == 403)
		{
			errorMessage =
				NSLocalizedStringFromTable(@"The server did not have permission to open the file..", @"HTTPFetcher", @"Error given when a file permissions problem prevents you opening or playing a file.");
		}
		else if (failureCode == 415)
		{
			errorMessage =
				NSLocalizedStringFromTable(@"The requested file couldn't be converted for streaming.", @"HTTPFetcher", @"Error given when a file can't be streamed.");
		}
		else if (failureCode == 500)
		{
			errorMessage =
				NSLocalizedStringFromTable(@"An internal server error occurred when requesting the file.", @"HTTPFetcher", @"Error given when an unknown problem occurs on the server.");
		}
		else
		{
			errorMessage = [NSString stringWithFormat:
				NSLocalizedStringFromTable(@"Server returned an HTTP error %ld.", @"HTTPFetcher", @"Error given when an unknown communication problem occurs. Placeholder is replaced with the error number."),
				failureCode];
		}

#if TARGET_OS_IPHONE		
		if (showAlerts)
		{
			UIAlertView *alert =
				[[UIAlertView alloc]
					initWithTitle:NSLocalizedStringFromTable(@"Connection Error", @"HTTPFetcher", @"Title of the error dialog used for any kind of connection or streaming error.")
					message:errorMessage
					delegate:nil
					cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"HTTPFetcher", @"Standard dialog dismiss button.")
					otherButtonTitles:nil];
			[alert show];    
			[alert release];
		}
#endif
		
		[self close];
		return;
	}
	
	//
	// Handle the content-length if present by preallocating.
	//
	[data release];
	NSInteger contentLength =
		[[responseHeaderFields objectForKey:@"Content-Length"] integerValue];
	if (contentLength > 0)
	{
		data = [[NSMutableData alloc] initWithCapacity:contentLength];
	}
	else
	{
		data = [[NSMutableData alloc] init];
	}
}

//
// connection:didReceiveData:
//
// Append the data chunck to the download.
//
- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)newData
{
	[data appendData:newData];
}

//
// connection:didReceiveAuthenticationChallenge:
//
// Show the authentication challenge alert to the user (or gives up if the
// failure count is non-zero).
//
- (void)connection:(NSURLConnection *)aConnection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)aChallenge
{
    if ([aChallenge previousFailureCount] <= 1)
	{
#if TARGET_OS_IPHONE		
		if (showAuthentication)
		{
			challenge = [aChallenge retain];
			
			passwordAlert =
				[[UIAlertView alloc]
					initWithTitle:NSLocalizedStringFromTable(@"Server requires login", @"HTTPFetcher", @"Title used for login dialog window.")
					message:@"\n\n\n"
					delegate:self
					cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"HTTPFetcher", @"Standard dialog cancel button.")
					otherButtonTitles:NSLocalizedStringFromTable(@"Login", @"HTTPFetcher", @"Button to submit login details and connect to the server"), nil];

			[passwordAlert setFrame:CGRectMake(0, 0, 300, 170)];

			UILabel *usernameLabel = [[[UILabel alloc] initWithFrame:CGRectMake(10,38,90,30)] autorelease];
			usernameLabel.font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
			usernameLabel.textColor = [UIColor whiteColor];
			usernameLabel.backgroundColor = [UIColor clearColor];
			usernameLabel.shadowColor = [UIColor blackColor];
			usernameLabel.shadowOffset = CGSizeMake(0,-1);
			usernameLabel.text = NSLocalizedStringFromTable(@"Name:", @"HTTPFetcher", @"Prompt for the username in the login dialog.");
			usernameLabel.textAlignment = UITextAlignmentRight;
			usernameLabel.autoresizingMask =
				UIViewAutoresizingFlexibleTopMargin |
				UIViewAutoresizingFlexibleBottomMargin;
			[passwordAlert addSubview:usernameLabel];

			usernameField = [[[UITextField alloc] initWithFrame:CGRectMake(104,38,168,30)] autorelease];
			usernameField.delegate = self;
			usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
			usernameField.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
			usernameField.keyboardAppearance = UIKeyboardAppearanceAlert;
			usernameField.backgroundColor = [UIColor whiteColor];
			usernameField.borderStyle = UITextBorderStyleBezel;
			usernameField.autoresizingMask =
				UIViewAutoresizingFlexibleTopMargin |
				UIViewAutoresizingFlexibleBottomMargin;
			[usernameField becomeFirstResponder];
			[passwordAlert addSubview:usernameField];

			UILabel *passwordLabel = [[[UILabel alloc] initWithFrame:CGRectMake(10,74,90,30)] autorelease];
			passwordLabel.font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
			passwordLabel.textColor = [UIColor whiteColor];
			passwordLabel.backgroundColor = [UIColor clearColor];
			passwordLabel.shadowColor = [UIColor blackColor];
			passwordLabel.shadowOffset = CGSizeMake(0,-1);
			passwordLabel.text = NSLocalizedStringFromTable(@"Password:", @"HTTPFetcher", @"Prompt for the password field in the login dialog.");
			passwordLabel.textAlignment = UITextAlignmentRight;
			passwordLabel.autoresizingMask =
				UIViewAutoresizingFlexibleTopMargin |
				UIViewAutoresizingFlexibleBottomMargin;
			[passwordAlert addSubview:passwordLabel];

			passwordField = [[[UITextField alloc] initWithFrame:CGRectMake(104,74,168,30)] autorelease];
			passwordField.secureTextEntry = YES;
			passwordField.delegate = self;
			passwordField.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
			passwordField.keyboardAppearance = UIKeyboardAppearanceAlert;
			passwordField.backgroundColor = [UIColor whiteColor];
			passwordField.borderStyle = UITextBorderStyleBezel;
			passwordField.autoresizingMask =
				UIViewAutoresizingFlexibleTopMargin |
				UIViewAutoresizingFlexibleBottomMargin;
			[passwordAlert addSubview:passwordField];
			
			[passwordAlert show];
			
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(willPresentAlertView:)
				name:UIDeviceOrientationDidChangeNotification
				object:nil];
		}
		else
#endif
		{
	        [[aChallenge sender] cancelAuthenticationChallenge:aChallenge];
			[self close];
		}
    }
	else
	{
        [[aChallenge sender] cancelAuthenticationChallenge:aChallenge];
		[self close];

		return;
    }
}

#if TARGET_OS_IPHONE		
//
// textFieldShouldReturn:
//
// Changes the default to YES and resign firstResponder.
//
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if ([textField isEqual:usernameField])
	{
		[passwordField becomeFirstResponder];
	}
	else if ([textField isEqual:passwordField])
	{
		UIAlertView *alertView = (UIAlertView *)passwordField.superview;
		[alertView.delegate alertView:alertView clickedButtonAtIndex:[alertView firstOtherButtonIndex]];
		[alertView dismissWithClickedButtonIndex:[alertView firstOtherButtonIndex] animated:YES];
	}
	return YES;
}
#endif

#if TARGET_OS_IPHONE		
//
// alertView:clickedButtonAtIndex:
//
// Sends the authentication when provided by the user.
//
// Parameters:
//    alertView - the alert view
//    buttonIndex - the button pressed
//
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	// Clicked the Submit button
	if (buttonIndex != [alertView cancelButtonIndex])
	{
		NSString *password = passwordField.text;
		if (password == nil)
		{
			password = @"";
		}
		
		NSURLCredential *newCredential =
			[NSURLCredential
				credentialWithUser:usernameField.text
				password:password
				persistence:NSURLCredentialPersistenceForSession];
		[[NSURLCredentialStorage sharedCredentialStorage]
			setDefaultCredential:newCredential
			forProtectionSpace:[challenge protectionSpace]];
		
		[[challenge sender]
			useCredential:newCredential
			forAuthenticationChallenge:challenge];
	}
	else
	{
        [[challenge sender] cancelAuthenticationChallenge:challenge];
		[self close];
	}
	
	[passwordAlert release];
	passwordAlert = nil;
	
	usernameField.delegate = nil;
	passwordField.delegate = nil;
	usernameField = nil;
	passwordField = nil;
	
	[challenge release];
	challenge = nil;
}
#endif

//
// connection:didFailWithError:
//
// Remove the connection and display an error message.
//
- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error
{
	if ([[error domain] isEqual:NSURLErrorDomain])
	{
		failureCode = [error code];
	}
	
#if TARGET_OS_IPHONE		
	if (showAlerts)
	{
		if ([error code] == -1012)
		{
			UIAlertView *alert =
				[[UIAlertView alloc]
					initWithTitle:NSLocalizedStringFromTable(@"Authentication Error", @"HTTPFetcher", @"Title for dialog rejecting username or password on login.")
					message:NSLocalizedStringFromTable(@"Username or password incorrect.", @"HTTPFetcher", @"Detail for dialog rejecting username or password on login.")
					delegate:nil
					cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"HTTPFetcher", @"Standard dialog dismiss button.")
					otherButtonTitles:nil];
			[alert show];    
			[alert release];
		}
		else if ([error code] == -1004)
		{
			UIAlertView *alert =
				[[UIAlertView alloc]
					initWithTitle:NSLocalizedStringFromTable(@"Server not running error", @"HTTPFetcher", @"Title for a specific connection error.")
					message:NSLocalizedStringFromTable(@"Cannot connect to server. A response was received that no server was running on the specified port.", @"HTTPFetcher", @"Detail for a specific connection error.")
					delegate:nil
					cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"HTTPFetcher", @"Standard dialog dismiss button.")
					otherButtonTitles:nil];
			[alert show];    
			[alert release];
		}
		else if ([error code] == -1001)
		{
			UIAlertView *alert =
				[[UIAlertView alloc]
					initWithTitle:NSLocalizedStringFromTable(@"Connection timeout", @"HTTPFetcher", @"Title for a specific connection error.")
					message:NSLocalizedStringFromTable(@"The server's computer could be off, taking too long to respond, or a firewall or router may be blocking the connection.", @"HTTPFetcher", @"Detail for a specific connection error.")
					delegate:nil
					cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"HTTPFetcher", @"Standard dialog dismiss button.")
					otherButtonTitles:nil];
			[alert show];    
			[alert release];
		}
		else
		{
			UIAlertView *alert =
				[[UIAlertView alloc]
					initWithTitle:NSLocalizedStringFromTable(@"Connection Error", @"HTTPFetcher", @"Title for a specific connection error.")
					message:[NSString stringWithFormat:
						NSLocalizedStringFromTable(@"Connection to server failed:\n%@", @"HTTPFetcher", @"Detail for a specific connection error."),
						[error localizedDescription]]
					delegate:nil
					cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"HTTPFetcher", @"Standard dialog dismiss button.")
					otherButtonTitles:nil];
			[alert show];    
			[alert release];
		}
	}
#endif

	[self close];
}

//
// connectionDidFinishLoading:
//
// When the connection is complete, parse the JSON and reconstruct
//
- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
	[self close];
}

//
// dealloc
//
// Releases instance memory.
//
- (void)dealloc
{
	[self cancel];
	
	[urlRequest release];
	urlRequest = nil;
	[responseHeaderFields release];
	responseHeaderFields = nil;

	[super dealloc];
}


@end
