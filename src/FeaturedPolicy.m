#import "FeaturedPolicy.h"
#import <objc/runtime.h>

NSString *FRQueryValue(NSURL *url, NSString *key) {
    for (NSString *part in [[url query] componentsSeparatedByString:@"&"]) {
        NSString *prefix = [key stringByAppendingString:@"="];
        if ([part hasPrefix:prefix]) return [[part substringFromIndex:[prefix length]] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    return nil;
}

BOOL FRIsFeaturedURL(NSURL *url) {
    if (!url) return NO;
    NSString *scheme = [[url scheme] lowercaseString];
    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) return NO;
    NSString *host = [[url host] lowercaseString];
    if (![host isEqualToString:@"itunes.apple.com"] &&
        ![host isEqualToString:@"apps.apple.com"] &&
        ![host isEqualToString:@"music.apple.com"] &&
        ![host isEqualToString:@"books.apple.com"] &&
        ![host isEqualToString:@"podcasts.apple.com"]) return NO;
    NSString *path = [url path];
    // Preserve the original iTunes U behavior; its retired feed is not replaced.
    if ([FRQueryValue(url, @"id") isEqualToString:@"27753"] || [FRQueryValue(url, @"mt") isEqualToString:@"10"]) return NO;
    // Only public storefront landing/grouping pages, never products or account routes.
    return [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewAppsMain"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewMusicMain"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewGrouping"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewMoviesMain"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewTVShowsMain"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewAudiobooksMain"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewTop"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewFeaturedSoftwareCategories"] ||
           [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewAutoSourcedGenrePage"];
}

BOOL FRIsPodcastDetailURL(NSURL *url) {
    NSString *scheme = [[url scheme] lowercaseString];
    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) return NO;
    NSString *host = [[url host] lowercaseString], *path = [url path];
    if (![host isEqualToString:@"podcasts.apple.com"] && ![host isEqualToString:@"itunes.apple.com"]) return NO;
    return [path isEqualToString:@"/WebObjects/MZStore.woa/wa/viewPodcast"] ||
        ([host isEqualToString:@"podcasts.apple.com"] && [path rangeOfString:@"/podcast/"].location != NSNotFound);
}

BOOL FRShouldPatchURL(NSURL *url) { return FRIsFeaturedURL(url) || FRIsPodcastDetailURL(url); }

NSURL *FRPublicFeedURL(NSURL *url) {
    if (!FRIsFeaturedURL(url)) return nil;
    NSString *country = [FRQueryValue(url, @"cc") lowercaseString];
    if ([country length] != 2 || [country rangeOfCharacterFromSet:[[objc_getClass("NSCharacterSet") characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz"] invertedSet]].location != NSNotFound) country = @"us";
    if ([[url path] hasSuffix:@"/viewGrouping"] && [FRQueryValue(url,@"id") isEqualToString:@"33"]) return [objc_getClass("NSURL") URLWithString:[objc_getClass("NSString") stringWithFormat:@"https://itunes.apple.com/%@/rss/toppodcasts/limit=30/json", country]];
    NSInteger genre = [FRQueryValue(url,@"genreId") integerValue];
    if ([[url path] hasSuffix:@"/viewTop"] && (genre == 36 || (genre >= 6000 && genre <= 7999))) {
        NSInteger tab = [FRQueryValue(url,@"selected-tab-index") integerValue];
        NSInteger pop = tab == 1 ? 44 : (tab == 2 ? 46 : 47);
        NSInteger page = MAX((NSInteger)1, MIN((NSInteger)10,[FRQueryValue(url,@"top-ten-m") integerValue])) - 1;
        return [objc_getClass("NSURL") URLWithString:[objc_getClass("NSString") stringWithFormat:@"https://itunes.apple.com/WebObjects/MZStore.woa/wa/topChartFragmentData?cc=%@&genreId=%ld&pageSize=30&popId=%ld&pageNumbers=%ld",country,(long)genre,(long)pop,(long)page]];
    }
    return nil;
}

NSString *FRReplacementStorefront(NSString *storefront) {
    // Preserve the country and language. Leave already-working client formats alone.
    if (![storefront isKindOfClass:[NSString class]] || ![storefront hasSuffix:@",9"]) return nil;
    NSString *prefix = [storefront substringToIndex:[storefront length] - 2];
    if (![prefix length]) return nil;
    return [prefix stringByAppendingString:@",4"];
}

BOOL FRPatchRequest(NSMutableURLRequest *request) {
    // NSURLRequest classes moved from Foundation to CFNetwork after iOS 5.
    // Runtime lookup avoids binding to the newer SDK's library ownership.
    if (![request isKindOfClass:objc_getClass("NSMutableURLRequest")]) return NO;
    if (![[request HTTPMethod] isEqualToString:@"GET"] || [request HTTPBody] || [request HTTPBodyStream]) return NO;
    if (!FRShouldPatchURL([request URL])) return NO;
    NSString *replacement = FRReplacementStorefront([request valueForHTTPHeaderField:@"X-Apple-Store-Front"]);
    if (!replacement) return NO;
    [request setValue:replacement forHTTPHeaderField:@"X-Apple-Store-Front"];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    return YES;
}
