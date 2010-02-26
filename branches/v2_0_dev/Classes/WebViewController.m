// Copyright (c) 2009 Imageshack Corp.
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products
//    derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// 

#import "WebViewController.h"
#import "TweetterAppDelegate.h"
#import "util.h"
#import "AboutController.h"

@implementation WebViewController

- (id)initWithRequest:(NSURLRequest*)request
{
	self = [super initWithNibName:@"WebView" bundle:nil];
	if(self)
	{
        _webView.delegate = self;
        
		_request = [request retain];
        _content = nil;
		self.hidesBottomBarWhenPushed = YES;
	}
	
	return self;
}

- (id)initWithHTML:(NSString*)content
{
    self = [self initWithRequest:nil];
    if (self)
    {
        _content = [[NSString alloc] initWithString:content];
        _webView.delegate = self;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"DEALLOC WEB VIEW CONTROLLER");
	_webView.delegate = nil;
	if(_webView.loading)
	{
		[_webView stopLoading];
		[TweetterAppDelegate decreaseNetworkActivityIndicator];
	}
    [_webView release];
	[_request release];
	[super dealloc];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
    
    _webView.delegate = self;
    if (_request)
        [_webView loadRequest:_request];
    else if (_content)
        [_webView loadHTMLString:_content baseURL:nil];
    
	self.navigationItem.title = NSLocalizedString(@"Loading...", @"");
	// important for view orientation rotation
	self.view.autoresizesSubviews = YES;
	self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	// starting the load, show the activity indicator in the status bar
	[TweetterAppDelegate increaseNetworkActivityIndicator];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[TweetterAppDelegate decreaseNetworkActivityIndicator];
	self.navigationItem.title = NSLocalizedString(@"Failed!", @"");
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[TweetterAppDelegate decreaseNetworkActivityIndicator];
	self.navigationItem.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSLog(@"Load request");
	
    TweetterAppDelegate *appDel = (TweetterAppDelegate*)[[UIApplication sharedApplication] delegate];
	[appDel startOpenGoogleMapsRequest:request];
	
	return YES;
}

@end

/*
 *  @interface OAuthWebController 
 *
 */
@implementation OAuthWebController

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    
    NSLog(@"%@", [url host]);
    
	return YES;
}

@end