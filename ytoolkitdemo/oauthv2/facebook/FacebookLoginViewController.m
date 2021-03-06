//
//Copyright (c) 2011, Hongbo Yang (hongbo@yang.me)
//All rights reserved.
//
//1. Redistribution and use in source and binary forms, with or without modification, are permitted 
//provided that the following conditions are met:
//
//2. Redistributions of source code must retain the above copyright notice, this list of conditions 
//and 
//the following disclaimer.
//
//3. Redistributions in binary form must reproduce the above copyright notice, this list of conditions
//and the following disclaimer in the documentation and/or other materials provided with the 
//distribution.
//
//Neither the name of the Hongbo Yang nor the names of its contributors may be used to endorse or 
//promote products derived from this software without specific prior written permission.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND 
//FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
//CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
//DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
//DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
//IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
//OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "FacebookLoginViewController.h"
#import "FacebookClientCredentials.h"

#import "SBJson/SBJson.h"
#import <ytoolkit/ymacros.h>
#import <ytoolkit/ycocoaadditions.h>
#import <ytoolkit/yoauthadditions.h>
#import <ytoolkit/yoauth.h>

@implementation FacebookLoginViewController
@synthesize webView;
@synthesize activityIndicator;
@synthesize grantType = _grantType;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    //scope references to http://developers.facebook.com/docs/reference/api/permissions/
    NSString * urlString = nil;
    
    if (AuthroizationCodeGrantType == self.grantType) {
        urlString = [@"https://www.facebook.com/dialog/oauth" requestAuthorizationCodeUrlStringByAddingClientId:kFacebookAppID
                                                                                                    redirectURI:kFacebookAppCallbackURL
                                                                                                          scope:@"user_status,read_stream"
                                                                                                          state:nil];
    }
    else if(ImplicitGrantType == self.grantType) {
        urlString = [@"https://www.facebook.com/dialog/oauth" requestImplicitGrantUrlStringByAddingClientId:kFacebookAppID
                                                                                                redirectURI:kFacebookAppCallbackURL
                                                                                                      scope:@"user_status,read_stream"
                                                                                                      state:nil];
    }
    NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [self.webView loadRequest:request];
    self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [self.activityIndicator startAnimating];
    _step = 0;
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [self setActivityIndicator:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
    [webView release];
    [activityIndicator release];
    [super dealloc];
}

#pragma mark - Network
- (void)requestFinished:(ASIHTTPRequest *)request 
{
    [self.activityIndicator stopAnimating];
    if (1 == _step && AuthroizationCodeGrantType == self.grantType) {
        NSDictionary * parameters = [request.responseString decodedUrlencodedParameters];
        YLOG(@"response:%@", request.responseString);
        self.accesstoken = [parameters objectForKey:YOAuthv2AccessToken];
        self.refreshtoken = [parameters objectForKey:YOAuthv2RefreshToken];
        id value = [parameters objectForKey:YOAuthv2ExpiresIn];
        if (YIS_INSTANCE_OF(value, NSNumber)) {
            self.expiresin = value;
        }
        else if (YIS_INSTANCE_OF(value, NSString)) {
            NSUInteger v = [value integerValue];
            self.expiresin = [NSNumber numberWithInteger:v];
        }
        if (self.accesstoken) {
            [self.delegate oauthv2LoginDidFinishLogging:self];
        }
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSLog(@"requstType:%d, step:%d, error: %@",self.grantType, _step, [request.error localizedDescription]);
}

#pragma mark - UIWebViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView 
{
    [self.activityIndicator stopAnimating];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSURL * url = request.URL;
    NSString * s = [url absoluteString];
    NSString * host = [s host];

    if ([host isEqualToString:[kFacebookAppCallbackURL host]]) {
        if (AuthroizationCodeGrantType == self.grantType) {
            NSDictionary * p = [s queryParameters];
            //        NSError * error = [NSError errorByCheckingOAuthv2RedirectURI:s];
            NSError * error = [NSError errorByCheckingOAuthv2RedirectURIParameters:p];
            if (nil == error) {
                
                NSString * authorizationCode = [p objectForKey:YOAuthv2AuthorizationCode];
                if (authorizationCode) {
                    
                    NSDictionary * parameters = YOAuthv2GetAccessTokenRequestParametersForAuthorizationCode(authorizationCode,
                                                                                                      kFacebookAppCallbackURL);
                    NSMutableDictionary * addParams = [NSMutableDictionary dictionaryWithDictionary:parameters];
                    [addParams setObject:kFacebookAppID forKey:YOAuthv2ClientId];
                    [addParams setObject:kFacebookAppSecret forKey:YOAuthv2ClientSecret];
                    
//                    NSString * urlString = [@"https://graph.facebook.com/oauth/access_token" URLStringByAddingParameters:addParams];
                    NSString * urlString = @"https://graph.facebook.com/oauth/access_token";
                    ASIHTTPRequest * r = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
                    [r setRequestMethod:@"POST"];
                    [r setPostBody:[[[[addParams queryString] dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] autorelease]];
                    //Note: it seems Facebook doesnot support HTTP Basic Authenticate scheme to transmit client_id and client_secret.
                    // So use post / htts to secure the client credentials
//                    r.username = kFacebookAppID;
//                    r.password = kFacebookAppSecret;
                    
                    r.delegate = self;
                    self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
                    [self.activityIndicator startAnimating];
                    _step = 1;
                    [r startAsynchronous];
                }
                else {
                    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"ytoolkit"
                                                                         message:@"Not denied and not authorized? I'm confused"
                                                                        delegate:nil
                                                               cancelButtonTitle:@"Anyway"
                                                               otherButtonTitles:nil];
                    [alertView show];
                    YRELEASE_SAFELY(alertView);
                }
            }
            else {
                NSString * reason = [error.userInfo objectForKey:@"error_reason"]; //this is a facebook specified key
                NSString * description = [error.userInfo objectForKey:YOAuthv2ErrorDescriptionKey];
                NSString * errorUri = [error.userInfo objectForKey:YOAuthv2ErrorURIKey];
                NSString * mesg = nil;
                if (reason) {
                    mesg = reason;
                }
                if (description) {
                    mesg = [mesg?mesg:@"" stringByAppendingFormat:@"(%@)", description];
                }
                if (errorUri) {
                    mesg = [mesg?mesg:@"" stringByAppendingFormat:@"please ref to:%@", errorUri];
                }
                UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                                     message:mesg
                                                                    delegate:nil
                                                           cancelButtonTitle:@"OK"
                                                           otherButtonTitles:nil];
                [alertView show];
                YRELEASE_SAFELY(alertView)
            }
            
        }
        else if (ImplicitGrantType == self.grantType) {
            NSString * f = [s fragment];
            if (f) {
                NSDictionary * p = [f decodedUrlencodedParameters];
                self.accesstoken = [p objectForKey:YOAuthv2AccessToken];
                id value = [p objectForKey:YOAuthv2ExpiresIn];
                if (YIS_INSTANCE_OF(value, NSNumber)) {
                    self.expiresin = value;
                }
                else if (YIS_INSTANCE_OF(value, NSString)) {
                    NSUInteger v = [value integerValue];
                    self.expiresin = [NSNumber numberWithInteger:v];
                }
                if (self.accesstoken) {
                    [self.delegate oauthv2LoginDidFinishLogging:self];
                }
                [self.delegate oauthv2LoginDidFinishLogging:self];
            }
        }
        return NO;
    }
    return YES;
}
@end
