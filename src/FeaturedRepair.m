#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <stdio.h>
#import "FeaturedPolicy.h"
#import "FeaturedRelay.h"
#import "FeaturedLog.h"

typedef void (*FRHookMessage)(Class, SEL, IMP, IMP *);
static id (*FROriginalNewRequest)(id, SEL, NSURL *);

void FRLog(NSString *message) {
    // Bounded local diagnostics: no URL queries, cookies, account identifiers or bodies.
    NSString *process = [[NSProcessInfo processInfo] processName];
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Logs/FeaturedRepair-%@.log", process];
    @synchronized([NSProcessInfo class]) {
        FILE *file = fopen([path fileSystemRepresentation], "a+");
        if (file) {
            fseek(file, 0, SEEK_END);
            if (ftell(file) > 16384) { fclose(file); file = fopen([path fileSystemRepresentation], "w"); }
            if (file) { fprintf(file, "%s\n", [message UTF8String]); fclose(file); }
        }
    }
    NSLog(@"[FeaturedRepair] %@", message);
}

static id FRNewRequest(id self, SEL command, NSURL *url) {
    id request = FROriginalNewRequest(self, command, url);
    if (!request || !FRShouldPatchURL([request URL])) return request;
    BOOL copied = ![request isKindOfClass:objc_getClass("NSMutableURLRequest")];
    NSMutableURLRequest *prepared = copied ? [request mutableCopy] : request;
    NSString *oldFormat = [[prepared valueForHTTPHeaderField:@"X-Apple-Store-Front"] copy];
    BOOL changed = FRPatchRequest(prepared);
    // Report only format suffix, not country/account-specific fields.
    NSString *suffix = [[oldFormat componentsSeparatedByString:@","] lastObject];
    FRLog([NSString stringWithFormat:@"Featured request %@ %@ format=%@ patched=%d", [[prepared URL] host], [[prepared URL] path], suffix ?: @"missing", changed]);
    [oldFormat release];
    if (copied) [request release]; // newRequestWithURL: returns a retained object.
    return prepared;
}

__attribute__((constructor)) static void FRInitialize(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Class operation = objc_getClass("ISStoreURLOperation");
    SEL selector = sel_registerName("newRequestWithURL:");
    FRHookMessage hook = (FRHookMessage)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (operation && class_getInstanceMethod(operation, selector) && hook) {
        hook(operation, selector, (IMP)&FRNewRequest, (IMP *)&FROriginalNewRequest);
        FRLog(@"v0.3.0 loaded; Featured request hook installed");
        FRInstallLayoutRelay();
        FRLog(@"v0.3.0 iPad layout relay installed");
    } else {
        FRLog([NSString stringWithFormat:@"v0.3.0 inactive: storeClass=%d method=%d substrate=%d", operation != Nil, operation && class_getInstanceMethod(operation, selector) != NULL, hook != NULL]);
    }
    [pool drain];
}
