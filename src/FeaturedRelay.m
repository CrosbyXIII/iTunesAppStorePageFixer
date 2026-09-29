#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "FeaturedPolicy.h"
#import "FeaturedLayout.h"
#import "FeaturedLog.h"

static NSString * const FRRelayKey = @"local.crosby.featuredrepair.relay";

@interface FRLayoutRelay : NSURLProtocol <NSURLConnectionDataDelegate> {
    NSURLConnection *_connection;
    NSURLResponse *_response;
    NSMutableData *_buffer;
    BOOL _streaming;
    BOOL _stopped;
}
@end

@implementation FRLayoutRelay
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([objc_getClass("NSURLProtocol") propertyForKey:FRRelayKey inRequest:request]) return NO;
    return FRIsFeaturedURL([request URL]) && [[request HTTPMethod] isEqualToString:@"GET"] &&
        ![request HTTPBody] && ![request HTTPBodyStream] &&
        [[request valueForHTTPHeaderField:@"X-Apple-Store-Front"] hasSuffix:@",4"];
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSURL *publicFeed = FRPublicFeedURL([[self request] URL]);
    // The public podcast feed needs no account context. Build a fresh request so
    // account cookies, authorization, and device headers cannot be forwarded.
    NSMutableURLRequest *forwarded = publicFeed ? [[objc_getClass("NSMutableURLRequest") alloc] initWithURL:publicFeed] : [[self request] mutableCopy];
    if (publicFeed) {
        [forwarded setHTTPShouldHandleCookies:NO];
        [forwarded setValue:@"iTunes-iPad/5.1.1 (1; 16GB; dt:12)" forHTTPHeaderField:@"User-Agent"];
        NSString *storefront = [[self request] valueForHTTPHeaderField:@"X-Apple-Store-Front"];
        if ([storefront hasSuffix:@",4"]) [forwarded setValue:[[storefront substringToIndex:[storefront length]-2] stringByAppendingString:@",9"] forHTTPHeaderField:@"X-Apple-Store-Front"];
    }
    [objc_getClass("NSURLProtocol") setProperty:[objc_getClass("NSNumber") numberWithBool:YES] forKey:FRRelayKey inRequest:forwarded];
    [forwarded setTimeoutInterval:20.0];
    FRLog(@"layout request started");
    _buffer = [[objc_getClass("NSMutableData") alloc] init];
    _connection = [[objc_getClass("NSURLConnection") alloc] initWithRequest:forwarded delegate:self startImmediately:NO];
    [forwarded release];
    [_connection scheduleInRunLoop:[objc_getClass("NSRunLoop") currentRunLoop] forMode:(NSString *)kCFRunLoopCommonModes];
    [_connection start];
}
- (void)stopLoading {
    _stopped = YES;
    [_connection cancel];
    [_connection release]; _connection = nil;
}
- (void)dealloc {
    [self stopLoading];
    [_response release];
    [_buffer release];
    [super dealloc];
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    (void)connection; (void)response;
    // Preserve Apple's redirect and the normal request context; never log headers.
    NSMutableURLRequest *forwarded = [[request mutableCopy] autorelease];
    [objc_getClass("NSURLProtocol") setProperty:[objc_getClass("NSNumber") numberWithBool:YES] forKey:FRRelayKey inRequest:forwarded];
    FRPatchRequest(forwarded);
    return forwarded;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    (void)connection;
    if (_stopped) return;
    [_response release]; _response = [response retain];
    [_buffer setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    (void)connection;
    if (_stopped) return;
    if (!_streaming && [_buffer length] + [data length] > 2 * 1024 * 1024) {
        _streaming = YES;
        [[self client] URLProtocol:self didReceiveResponse:_response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[self client] URLProtocol:self didLoadData:_buffer];
        [_buffer setLength:0];
    }
    if (_streaming) [[self client] URLProtocol:self didLoadData:data];
    else [_buffer appendData:data];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    (void)connection;
    if (_stopped) return;
    [self retain];
    if (!_streaming) {
        NSInteger status = [_response respondsToSelector:@selector(statusCode)] ? [(id)_response statusCode] : 0;
        NSData *rendered = nil;
        @try {
            if (status == 200) rendered = FRIPadPage(_buffer, [_response URL]);
        } @catch (NSException *exception) {
            (void)exception;
            FRLog(@"layout parser declined response; using original page");
        }
        NSData *data = rendered ?: _buffer;
        NSURLResponse *response = _response;
        if (rendered) {
            // New content is uncompressed HTML; do not retain the source's XML/gzip headers.
            NSDictionary *headers = [objc_getClass("NSDictionary") dictionaryWithObjectsAndKeys:@"text/html; charset=utf-8", @"Content-Type", @"no-store", @"Cache-Control", nil];
            response = [[[objc_getClass("NSHTTPURLResponse") alloc] initWithURL:[[self request] URL] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headers] autorelease];
            FRLog([objc_getClass("NSString") stringWithFormat:@"iPad layout rendered for %@ (%lu bytes)", [[_response URL] host], (unsigned long)[data length]]);
        }
        else FRLog([objc_getClass("NSString") stringWithFormat:@"layout passthrough status=%ld bytes=%lu", (long)status, (unsigned long)[data length]]);
        [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[self client] URLProtocol:self didLoadData:data];
    }
    [[self client] URLProtocolDidFinishLoading:self];
    [self stopLoading];
    [self release];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    (void)connection;
    if (_stopped) return;
    [self retain];
    FRLog([objc_getClass("NSString") stringWithFormat:@"layout connection failed domain=%@ code=%ld", [error domain], (long)[error code]]);
    [[self client] URLProtocol:self didFailWithError:error];
    [self stopLoading];
    [self release];
}
@end

void FRInstallLayoutRelay(void) {
    [objc_getClass("NSURLProtocol") registerClass:[FRLayoutRelay class]];
}
