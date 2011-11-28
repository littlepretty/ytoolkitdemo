//Copyright 2011 Hongbo YANG (hongbo@yang.me). All rights reserved.
//
//Redistribution and use in source and binary forms, with or without modification, are
//permitted provided that the following conditions are met:
//
//1. Redistributions of source code must retain the above copyright notice, this list of
//conditions and the following disclaimer.
//
//2. Redistributions in binary form must reproduce the above copyright notice, this list
//of conditions and the following disclaimer in the documentation and/or other materials
//provided with the distribution.
//
//THIS SOFTWARE IS PROVIDED BY Hongbo YANG ''AS IS'' AND ANY EXPRESS OR IMPLIED
//WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Hongbo YANG OR
//CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//The views and conclusions contained in the software and documentation are those of the
//authors and should not be interpreted as representing official policies, either expressed
//or implied, of Hongbo YANG.

#import "QQweiboOAuthv1LoginViewController.h"

#import "QQWeiboClientCredentials.h"

#import "SBJson/SBJson.h"
#import <ytoolkit/ymacros.h>
#import <ytoolkit/ycocoaadditions.h>
#import <ytoolkit/yoauthadditions.h>
#import <ytoolkit/yoauth.h>

@implementation QQweiboOAuthv1LoginViewController
@synthesize webView;
@synthesize activityIndicator;
@synthesize verifier = _verifier;
@synthesize openid = _openid;
@synthesize openkey = _openkey;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    NSString * urlString = @"https://open.t.qq.com/cgi-bin/request_token";
    ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.delegate = self;
    [request setRequestMethod:@"GET"];
    [request prepareQQOAuthv1QueryURIUsingConsumerKey:kQQweiboApiKey
                                  consumerSecretKey:kQQweiboApiSecret
                                              token:nil
                                        tokenSecret:nil
                                    signatureMethod:YOAuthv1SignatureMethodHMAC_SHA1
                                           verifier:nil
                                           callback:@"http://ytoolkitdemo.yang.me"];
    
    _step = 0;
    self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [self.activityIndicator startAnimating];
    [request startAsynchronous];
    
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [self setActivityIndicator:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)dealloc {
    [webView release];
    [activityIndicator release];
    self.verifier = nil;
    self.openkey = nil;
    self.openid = nil;
    [super dealloc];
}

#pragma mark - Network
- (void)requestFinished:(ASIHTTPRequest *)request {
    YLOG(@"response:%@", request.responseString);
    NSDictionary * params = [request.responseString decodedUrlencodedParameters];
    self.accesstoken = [params objectForKey:YOAuthv1OAuthTokenKey];
    self.tokensecret = [params objectForKey:YOAuthv1OAuthTokenSecretKey];
    NSString * confirmed = [params objectForKey:YOAuthv1OAuthCallbackConfirmedKey];
    
    if(confirmed)NSLog(@"callback is confirmed:%@", confirmed);
    
    if (self.accesstoken && self.tokensecret) {
        if (0 == _step) {
            NSString * url = [NSString stringWithFormat:@"https://open.t.qq.com/cgi-bin/authorize?%@=%@", YOAuthv1OAuthTokenKey, self.accesstoken];
            NSMutableURLRequest * r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
            [self.webView loadRequest:r];
            self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
            [self.activityIndicator startAnimating];
            _step = 1;
        }
        else {
            [self.delegate oauthv1LoginDidFinishLogging:self];
        }
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    UIAlertView * alertView = [[[UIAlertView alloc] initWithTitle:[[self class] description]
                                                          message:[request.error localizedDescription]
                                                         delegate:nil
                                                cancelButtonTitle:@"OK"
                                                otherButtonTitles:nil] autorelease];
    [alertView show];
    
    YLOG(@"response:%@", request.responseString);
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
    YLOG(@"load Request to: %@", s);
    if ([host isEqualToString:@"ytoolkitdemo.yang.me"]) {
        NSDictionary * p = [s queryParameters];
        self.verifier = [p objectForKey:YOAuthv1OAuthVerifierKey];
        self.openid = [p objectForKey:@"openid"]; //QQ specified key/value
        self.openkey = [p objectForKey:@"openkey"]; 
        
        ASIHTTPRequest * r = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"https://open.t.qq.com/cgi-bin/access_token"]];
        [r setRequestMethod:@"POST"];
        r.delegate = self;
        [r prepareQQOAuthv1QueryURIUsingConsumerKey:kQQweiboApiKey
                                           consumerSecretKey:kQQweiboApiSecret
                                                       token:self.accesstoken
                                                 tokenSecret:self.tokensecret
                                             signatureMethod:YOAuthv1SignatureMethodHMAC_SHA1
                                                    verifier:self.verifier
                                                    callback:nil];
        _step = 1;
        self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        [self.activityIndicator startAnimating];
        [r startAsynchronous];
        
        return NO;
    }
    return YES;
}

@end