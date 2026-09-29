#import <Foundation/Foundation.h>
#import "FeaturedRelay.h"
#import "Fixtures.h"
#include <assert.h>

static NSData *fixture;
static NSInteger responseStatus;
static BOOL shouldFail, shouldWait;
static NSUInteger networkRequests;
void FRLog(NSString *message) { (void)message; }

@interface FRFixtureProtocol : NSURLProtocol @end
@implementation FRFixtureProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return [[[request URL] host] isEqualToString:@"apps.apple.com"] || [[[request URL] host] isEqualToString:@"itunes.apple.com"];
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    networkRequests++;
    if ([[[self request] URL].host isEqualToString:@"itunes.apple.com"]) {
        assert(![[self request] valueForHTTPHeaderField:@"Authorization"]);
        assert(![[self request] valueForHTTPHeaderField:@"Cookie"]);
        assert(![[self request] valueForHTTPHeaderField:@"X-Dsid"]);
        assert(![[self request] HTTPShouldHandleCookies]);
    }
    if (shouldWait) return;
    if (shouldFail) {
        [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
        return;
    }
    NSHTTPURLResponse *response = [[[NSHTTPURLResponse alloc] initWithURL:[[self request] URL] statusCode:responseStatus HTTPVersion:@"HTTP/1.1" headerFields:nil] autorelease];
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    for (NSUInteger position = 0; position < [fixture length]; position += 16384) {
        NSUInteger length = MIN((NSUInteger)16384, [fixture length] - position);
        [[self client] URLProtocol:self didLoadData:[fixture subdataWithRange:NSMakeRange(position, length)]];
    }
    [[self client] URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end

@interface FRTestClient : NSObject <NSURLProtocolClient> {
@public
    NSMutableData *body;
    NSURLResponse *response;
    NSError *error;
    NSUInteger finishes;
}
@end
@implementation FRTestClient
- (id)init { if ((self = [super init])) body = [[NSMutableData alloc] init]; return self; }
- (void)dealloc { [body release]; [response release]; [error release]; [super dealloc]; }
- (void)URLProtocol:(NSURLProtocol *)p didReceiveResponse:(NSURLResponse *)r cacheStoragePolicy:(NSURLCacheStoragePolicy)s { (void)p; (void)s; response = [r retain]; }
- (void)URLProtocol:(NSURLProtocol *)p didLoadData:(NSData *)d { (void)p; [body appendData:d]; }
- (void)URLProtocolDidFinishLoading:(NSURLProtocol *)p { (void)p; finishes++; }
- (void)URLProtocol:(NSURLProtocol *)p didFailWithError:(NSError *)e { (void)p; error = [e retain]; }
- (void)URLProtocol:(NSURLProtocol *)p wasRedirectedToRequest:(NSURLRequest *)r redirectResponse:(NSURLResponse *)s { (void)p; (void)r; (void)s; assert(NO); }
- (void)URLProtocol:(NSURLProtocol *)p cachedResponseIsValid:(NSCachedURLResponse *)r { (void)p; (void)r; }
- (void)URLProtocol:(NSURLProtocol *)p didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)c { (void)p; (void)c; assert(NO); }
- (void)URLProtocol:(NSURLProtocol *)p didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)c { (void)p; (void)c; }
@end

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSURLProtocol registerClass:[FRFixtureProtocol class]];
    FRInstallLayoutRelay();
    Class relay = NSClassFromString(@"FRLayoutRelay");
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://apps.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?id=25204"]];
    [request setValue:@"143441-1,4" forHTTPHeaderField:@"X-Apple-Store-Front"];
    assert([relay canInitWithRequest:request]);
    for (int test = 0; test < 5; test++) {
        responseStatus = test == 1 ? 500 : 200;
        shouldFail = test == 3;
        shouldWait = test == 4;
        fixture = test == 2 ? [NSMutableData dataWithLength:2*1024*1024+50] : FRAppFixture();
        FRTestClient *client = [[FRTestClient alloc] init];
        NSURLProtocol *protocol = [[relay alloc] initWithRequest:request cachedResponse:nil client:client];
        NSUInteger before = networkRequests;
        [protocol startLoading];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
        while (!client->finishes && !client->error && [deadline timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            if (shouldWait && networkRequests > before) break;
        }
        assert(networkRequests == before + 1); // No protocol recursion.
        if (test == 0) {
            NSString *html = [[[NSString alloc] initWithData:client->body encoding:NSUTF8StringEncoding] autorelease];
            assert([html rangeOfString:@"class=\"fr-grid\""].location != NSNotFound);
            assert([[client->response MIMEType] isEqualToString:@"text/html"]);
        } else if (test == 1 || test == 2) assert([client->body isEqual:fixture]);
        else if (test == 3) assert([client->error code] == NSURLErrorTimedOut);
        else { [protocol stopLoading]; assert(client->finishes == 0 && !client->error); }
        assert(client->finishes == (test < 3 ? 1 : 0));
        [protocol stopLoading];
        [protocol release];
        [client release];
    }
    [request setHTTPMethod:@"POST"];
    assert(![relay canInitWithRequest:request]);
    for (NSString *kind in [NSArray arrayWithObjects:@"podcasts",@"charts",nil]) {
        shouldWait = shouldFail = NO; responseStatus = 200;
        BOOL podcast = [kind isEqualToString:@"podcasts"];
        fixture = (podcast ? FRPodcastFixture() : FRChartFixture());
        NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:podcast ? @"https://podcasts.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?cc=us&id=33" : @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTop?cc=us&genreId=36"]];
        [r setValue:@"143441-1,4" forHTTPHeaderField:@"X-Apple-Store-Front"];
        for (NSString *header in [NSArray arrayWithObjects:@"Authorization",@"Cookie",@"X-Dsid",nil]) [r setValue:@"must-not-forward" forHTTPHeaderField:header];
        FRTestClient *client = [[FRTestClient alloc] init];
        NSURLProtocol *protocol = [[relay alloc] initWithRequest:r cachedResponse:nil client:client];
        NSUInteger before = networkRequests;
        [protocol startLoading];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
        while (!client->finishes && !client->error && [deadline timeIntervalSinceNow]>0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        assert(client->finishes == 1 && !client->error);
        assert(networkRequests == before+1);
        assert([[client->response URL] isEqual:[r URL]]);
        NSString *html = [[[NSString alloc] initWithData:client->body encoding:NSUTF8StringEncoding] autorelease];
        assert([html rangeOfString:podcast ? @"Top Podcasts" : @"Top iPad Charts"].location!=NSNotFound);
        [protocol stopLoading]; [protocol release]; [client release];
    }
    printf("PASS: relay transformation, error/oversize passthrough, timeout, cancellation, no recursion, and credential-free public feeds\n");
    [pool drain];
    return 0;
}
