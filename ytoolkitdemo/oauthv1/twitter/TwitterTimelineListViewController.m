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

#import "TwitterTimelineListViewController.h"
#import "TwitterLoginViewController.h"

#import <ytoolkit/ymacros.h>
#import "ASIHTTPRequest.h"
#import "ASIHTTPRequest+YOAuthv1Request.h"
#import "TwitterClientCredentials.h"
#import "SBJson/SBJson.h"

@implementation TwitterTimelineListViewController

+ (NSString *)description {
    return @"Twitter OAuth 1.0 demo";
}


#pragma mark - View lifecycle

#pragma mark - network
- (void)loadFeedStream {
    if (self.accesstoken && self.tokensecret) {
        ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://api.twitter.com/1/statuses/home_timeline.json"]];
        request.delegate = self;
        [request prepareOAuthv1AuthorizationHeaderUsingConsumerKey:kTwitterConsumerKey
                                                 consumerSecretKey:kTwitterConsumerSecretKey
                                                             token:self.accesstoken
                                                       tokenSecret:self.tokensecret 
                                                             realm:nil];
        [request startAsynchronous];
    }
}

- (void)startLogin
{
    TwitterLoginViewController * login = [[[TwitterLoginViewController alloc] initWithNibName:@"TwitterLoginViewController" bundle:nil] autorelease];
    login.delegate = self;
    [self presentModalViewController:login animated:YES];
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

- (void)requestFinished:(ASIHTTPRequest *)request {
    YLOG(@"response:%@", request.responseString);
    id value = [request.responseString JSONValue];
    if (YIS_INSTANCE_OF(value, NSArray)) {
        [self.messages removeAllObjects];
        for (id item in value) {
            if (YIS_INSTANCE_OF(item, NSDictionary)) {
                NSString * text = [item objectForKey:@"text"];
                if (YIS_INSTANCE_OF(text, NSString)) {
                    [self.messages addObject:text];
                }
            }
        }
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - properties

#define ACCESSTOKEN_KEY @"twitteraccesstoken"
#define TOKENSECRET_KEY  @"twittertokensecret"

- (void)setAccesstoken:(NSString *)accesstoken {
    [super setAccesstoken:accesstoken];
    if ([super accesstoken]) {
        [[NSUserDefaults standardUserDefaults] setObject:self.accesstoken forKey:ACCESSTOKEN_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)accesstoken {
    
    NSString * token = [super accesstoken];
    if (nil == token) {
        token = [[NSUserDefaults standardUserDefaults] objectForKey:ACCESSTOKEN_KEY];
        self.accesstoken = token;
    }
    return token;
}


- (void)setTokensecret:(NSString *)tokensecret
{
    [super setTokensecret:tokensecret];
    if ([super tokensecret]) {
        [[NSUserDefaults standardUserDefaults] setObject:self.tokensecret forKey:TOKENSECRET_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)tokensecret {
    
    NSString * token = [super tokensecret];
    if (nil == token) {
        token = [[NSUserDefaults standardUserDefaults] objectForKey:TOKENSECRET_KEY];
        self.tokensecret = token;
    }
    return token;
}

@end
